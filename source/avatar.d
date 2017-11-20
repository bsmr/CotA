module avatar;

// dfmt off
private import std.file;
private import std.path;
private import std.stdio;
private import std.string;
// dfmt on

private string getDate(const char[] line, string search)
{
  if (line.indexOf('[') == 0)
  {
    immutable auto searchPos = (search.length > 0
        ? cast(long) line.indexOf(search) : cast(long) line.length);
    if (searchPos > 0)
    {
      immutable auto bracketPos = line.indexOf("] ");
      if ((bracketPos > 1) && (bracketPos < searchPos))
        return line[1 .. bracketPos].dup();
    }
  }

  return "";
}

private string getText(const char[] line, string date, string search)
{
  string start = "[" ~ date ~ "] ";
  if (line.startsWith(start) && ((search.length == 0) || (line.indexOf(search) > 0)))
    return line[start.length .. $].dup();

  return "";
}

/// Class to read stat entries from SotA chat logs.
public class AvatarLogData
{
  private enum m_adventurerLevel = "AdventurerLevel:";
  private string m_path;

  private bool isPathValid() const
  {
    return exists(m_path) && isDir(m_path);
  }

  private auto getLogFileEntries(string avatar = "") const
  {
    return dirEntries(m_path, "SotAChatLog_%1_????-??-??.txt".replace("%1",
        (avatar.length == 0 ? "*" : avatar.replace(" ", "_"))), SpanMode.shallow);
  }

  /// Constructor.
  this(string path)
  {
    m_path = path;
  }

  /// Returns a list of avatar names.
  string[] getAvatars() const
  {
    if (!isPathValid())
      return [];

    enum startText = "SotAChatLog_";
    int[string] nameSet;

    foreach (fileName; getLogFileEntries())
    {
      string name = fileName.baseName();
      immutable auto pos = name.lastIndexOf('_');
      if (!(pos > startText.length))
        continue;

      // Extract the avatar name.
      name = name[startText.length .. pos];
      if (name.length == 0)
        continue;

      // Replace underscores with spaces and add the name to the set.
      ++nameSet[name.replace("_", " ")];
    }

    if (nameSet.length == 0)
      return [];

    // Copy the names to an array.
    string[] names;
    foreach (name, value; nameSet)
      names ~= name;

    return names;
  }

  string[] getStatDates(string avatar) const
  {
    if ((avatar.length == 0) || !isPathValid())
      return [];

    string[] dates;
    foreach (fileName; getLogFileEntries(avatar))
    {
      // Search the log file for stat entries.
      foreach (line; File(fileName, "r").byLine())
      {
        string date = getDate(line, m_adventurerLevel);
        if (date.length > 0)
          dates ~= date;
      }
    }

    return dates;
  }

  string[2][] getStats(string avatar, string date) const
  {
    if ((avatar.length == 0) || (date.length == 0) || !isPathValid())
      return [];

    foreach (fileName; getLogFileEntries(avatar))
    {
      // Search the log file for the "/stats" entry that matches the date.
      string stats;
      foreach (line; File(fileName, "r").byLine())
      {
        stats = getText(line, date, m_adventurerLevel);
        if (stats.length > 0)
          break;
      }

      if (stats.length == 0)
        continue;

      // Split the text at whitespace.
      auto fields = stats.split();

      // Create an array of name/value pairs.
      string[2][] statList;
      while (fields.length >= 2)
      {
        string name = fields[0];
        fields = fields[1 .. $];

        if (name.endsWith(":"))
        {
          // Exclude colon from the stat name. 
          statList ~= [name[0 .. $ - 1], fields[0]];
          fields = fields[1 .. $];
        }
      }

      return statList;
    }

    return [];
  }
}