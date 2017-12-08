module avatar;

// dfmt off
private import std.file;
private import std.path;
private import std.stdio;
private import std.string;
private import std.typecons;
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

  return [];
}

private string getText(const char[] line, string date, string search)
{
  string start = "[" ~ date ~ "] ";
  if (line.startsWith(start) && ((search.length == 0) || (line.indexOf(search) > 0)))
    return line[start.length .. $].dup();

  return [];
}

/**
 * Class to read stat entries from SotA chat logs.
 */
class AvatarLogData
{
  private enum Strings
  {
    logNameStart = "SotAChatLog_",
    adventurerLevel = "AdventurerLevel: "
  }

  private string m_path;

  private bool isPathValid() const
  {
    return exists(m_path) && isDir(m_path);
  }

  private auto getLogFileEntries(string avatar = []) const
  {
    return dirEntries(m_path, Strings.logNameStart ~ (avatar.length > 0
        ? avatar.replace(" ", "_") : "*") ~ "_????-??-??.txt", SpanMode.shallow);
  }

  /**
   * Constructor.
   */
  this(string path)
  {
    m_path = path;
  }

  /**
   * Returns a list of avatar names.
   */
  string[] getAvatars() const
  {
    if (!isPathValid())
      return [];

    int[string] nameSet;
    foreach (fileName; getLogFileEntries())
    {
      string name = fileName.baseName();
      immutable auto pos = name.lastIndexOf('_');
      if (!(pos > Strings.logNameStart.length))
        continue;

      // Extract the avatar name.
      name = name[Strings.logNameStart.length .. pos];
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

  /**
   * Returns the dates that "/stats" was used for the specified avatar.
   */
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
        string date = getDate(line, Strings.adventurerLevel);
        if (date.length > 0)
          dates ~= date;
      }
    }

    return dates;
  }

  /**
   * Tuple of name and value for stats.
   */
  alias Stat = Tuple!(string, "name", string, "value");

  /**
   * Returns the stats, as name/value pairs, for the specified avatar and date.
   */
  Stat[] getStats(string avatar, string date) const
  {
    if ((avatar.length == 0) || (date.length == 0) || !isPathValid())
      return [];

    foreach (fileName; getLogFileEntries(avatar))
    {
      // Search the log file for the "/stats" entry that matches the date.
      string stats;
      foreach (line; File(fileName, "r").byLine())
      {
        stats = getText(line, date, Strings.adventurerLevel);
        if (stats.length > 0)
          break;
      }

      if (stats.length == 0)
        continue;

      // Split the text at whitespace.
      auto fields = stats.split();

      // Create an array of name/value pairs.
      Stat[] statList;
      while (fields.length >= 2)
      {
        string name = fields[0];
        fields = fields[1 .. $];

        if (name.endsWith(":"))
        {
          // Exclude the trailing colon from the stat name. 
          statList ~= Stat(name[0 .. $ - 1], fields[0]);
          fields = fields[1 .. $];
        }
      }

      return statList;
    }

    return [];
  }
}
