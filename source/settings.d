module settings;

// dfmt off
private import glib.Util;
private import std.file;
private import std.json;
// dfmt on

/// Simple application settings object.
class Settings
{
  private enum
  {
    m_logFolder = "Log Folder",
    m_avatar = "Avatar",
    m_notes = " Notes"
  }

  private string m_filePath;
  private JSONValue m_json;

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

  string getLogFolder() const
  {
    string logFolder;
    if (m_json.type == JSON_TYPE.OBJECT)
    {
      if (auto value = m_logFolder in m_json)
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

  void setLogFolder(string logFolder)
  {
    m_json[m_logFolder] = logFolder;
  }

  /// Gets the current avatar name.
  string getAvatar() const
  {
    if (m_json.type == JSON_TYPE.OBJECT)
    {
      if (auto value = m_avatar in m_json)
        return value.str;
    }

    return "";
  }

  /// Sets the current avatar name.
  void setAvatar(string avatar)
  {
    m_json[m_avatar] = avatar;
  }

  /// Get the notes for the specified avatar.
  string getNotes(string avatar) const
  {
    if ((avatar.length > 0) && (m_json.type == JSON_TYPE.OBJECT))
    {
      if (auto value = (avatar ~ m_notes) in m_json)
        return value.str;
    }

    return "";
  }

  /// Set the notes for the specified avatar.
  void setNotes(string avatar, string notes)
  {
    if (avatar.length == 0)
      return;

    m_json[avatar ~ m_notes] = notes;
  }

  /// Store the current settings.
  void store() const
  {
    if (!m_json.isNull())
      write(m_filePath, m_json.toString());
  }
}
