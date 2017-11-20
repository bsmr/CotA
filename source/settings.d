module settings;

// dfmt off
private import glib.Util;
private import std.file;
private import std.json;
// dfmt on

/// Simple application settings object.
class Settings
{
  private enum Keys
  {
    logFolder = "Log Folder",
    avatar = "Avatar",
    notes = " Notes"
  }

  private string m_filePath;
  private JSONValue m_json;

  private bool store() const
  {
    if (m_json.type != JSON_TYPE.OBJECT)
      return false;

    write(m_filePath, m_json.toString());
    return true;
  }

  /// Construction.
  this(string appPath)
  {
    m_filePath = appPath ~ ".json";
    if (exists(m_filePath))
    {
      auto text = readText(m_filePath);
      if (text.length > 0)
        m_json = parseJSON(text);
    }
  }

  // Gets the log folder path.
  string getLogFolder() const
  {
    string logFolder;
    if (m_json.type == JSON_TYPE.OBJECT)
    {
      if (auto value = Keys.logFolder in m_json)
        logFolder = value.str;
    }

    if (logFolder.length == 0)
    {
      version (linux)
      {
        logFolder = Util.getHomeDir() ~ "/.config/Portalarium/Shroud of the Avatar/ChatLogs";
      }
      version (OSX)
      {
        logFolder = Util.getHomeDir() ~ "/.config/Portalarium/Shroud of the Avatar/ChatLogs";
      }
      version (Windows)
      {
        logFolder = Util.getHomeDir() ~ "/AppData/Roaming/Portalarium/Shroud of the Avatar/ChatLogs";
      }
    }

    return logFolder;
  }

  // Sets the log folder path.
  bool setLogFolder(string logFolder)
  {
    if (logFolder == getLogFolder())
      return false;

    m_json[Keys.logFolder] = logFolder;
    return store();
  }

  /// Gets the current avatar name.
  string getAvatar() const
  {
    if (m_json.type == JSON_TYPE.OBJECT)
    {
      if (auto value = Keys.avatar in m_json)
        return value.str;
    }

    return "";
  }

  /// Sets the current avatar name.
  bool setAvatar(string avatar)
  {
    if (avatar == getAvatar())
      return false;

    m_json[Keys.avatar] = avatar;
    return store();
  }

  /// Get the notes for the specified avatar.
  string getNotes(string avatar) const
  {
    if ((avatar.length > 0) && (m_json.type == JSON_TYPE.OBJECT))
    {
      if (auto value = (avatar ~ Keys.notes) in m_json)
        return value.str;
    }

    return "";
  }

  /// Set the notes for the specified avatar.
  bool setNotes(string avatar, string notes)
  {
    if ((avatar.length == 0) || (notes == getNotes(avatar)))
      return false;

    m_json[avatar ~ Keys.notes] = notes;
    return store();
  }
}