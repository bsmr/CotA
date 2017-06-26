#include "AvatarDao.h"

bool AvatarDao::_preParse(const QByteArray & line, QByteArray & date, QByteArray & stats)
{
  int pos = line.indexOf("AdventurerLevel:");
  if (pos > 0)
  {
    pos = line.indexOf("] ");
    if (pos > 0)
    {
      date = line.mid(1, pos - 1);
      stats = line.mid(pos + 2);
      return true;
    }
  }

  return false;
}

QFileInfoList AvatarDao::_getFileinfoList(const QString & avatar) const
{
  if (avatar.isEmpty())
  {
    // Return a list of all the log files.
    return m_logDir.entryInfoList({QStringLiteral("SotAChatLog_*_???\?-?\?-??.txt")});
  }

  // Return a list of log files matching the avatar's name.
  return m_logDir.entryInfoList({QStringLiteral("SotAChatLog_%1_???\?-?\?-??.txt").arg(QString(avatar).replace(QChar(' '), QChar('_')))});
}

AvatarDao::AvatarDao()
{
}

AvatarDao::AvatarDao(const QString & logFolder):
  m_logDir(logFolder, {}, QDir::Name | QDir::IgnoreCase, QDir::Files)
{
}

AvatarDao::AvatarDao(const AvatarDao & other):
  m_logDir(other.m_logDir)
{
}

AvatarDao &AvatarDao::operator =(const AvatarDao & other)
{
  return *new (this) AvatarDao(other);
}

QString AvatarDao::path() const
{
  return m_logDir.path();
}

QStringList AvatarDao::getAvatars() const
{
  auto fileInfoList = _getFileinfoList();
  if (fileInfoList.isEmpty())
    return {};

  static const QString startText = QStringLiteral("SotAChatLog_");
  QSet<QString> nameSet;

  // Extract the avatar names.
  for (const auto & fileInfo: fileInfoList)
  {
    QString name = fileInfo.baseName();
    int pos = name.lastIndexOf(QChar('_'));
    if (pos <= startText.length())
      continue;

    name = name.mid(startText.length(), pos - startText.length());
    if (name.isEmpty())
      continue;

    // Replace underscores with spaces and add the name to the set.
    nameSet.insert(name.replace(QChar('_'), QChar(' ')));
  }

  if (nameSet.empty())
    return {};

  // Copy the names to a list.
  QStringList nameList;
  for (const auto &name: nameSet)
    nameList.append(name);

  return nameList;
}

QStringList AvatarDao::getStatDates(const QString & avatar) const
{
  auto fileInfoList = _getFileinfoList(avatar);
  if (fileInfoList.isEmpty())
    return {};

  QStringList dates;
  for (auto &fileInfo: fileInfoList)
  {
    // Attempt to open the log file.
    QFile file(fileInfo.filePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
      continue;

    // Search for the "/stats" entries.
    while (!file.atEnd())
    {
      QByteArray date;
      QByteArray stats;
      if (_preParse(file.readLine(), date, stats))
         dates.append(date);
    }
  }

  return dates;
}

QList<AvatarDao::StatEntry> AvatarDao::getStats(const QString & avatar, const QString & date) const
{
  // Get a list of log files that match the avatar's name ("\?" is used here to avoid warnings about trigraphs).
  auto fileInfoList = _getFileinfoList(avatar);
  if (fileInfoList.isEmpty())
    return {};

  for (auto &fileInfo: fileInfoList)
  {
    // Attempt to open the log file.
    QFile file(fileInfo.filePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
      continue;

    QByteArray checkDate = date.toUtf8();
    QByteArray stats;

    // Search for the "/stats" entry that matches dateTime.
    while (!file.atEnd())
    {
      QByteArray parsedStats;
      QByteArray parsedDate;
      if (_preParse(file.readLine(), parsedDate, parsedStats) && (parsedDate == checkDate))
      {
        stats = parsedStats;
        break;
      }
    }

    if (stats.isEmpty())
      continue;

    // Split the text at spaces.
    auto fields = stats.split(' ');

    // Create a collection of StatEntry items.
    QList<StatEntry> items;
    while (fields.size() >= 2)
    {
      const QString name = fields.takeFirst();
      const QString value = fields.takeFirst();
      items.append(StatEntry(name, value));
    }

    return items;
  }

  return {};
}

AvatarDao::StatEntry::StatEntry()
{
}

AvatarDao::StatEntry::StatEntry(const QString & name, const QString & value):
  m_name(name),
  m_value(value)
{
}

AvatarDao::StatEntry::StatEntry(const AvatarDao::StatEntry & other):
  m_name(other.m_name),
  m_value(other.m_value)
{
}

AvatarDao::StatEntry & AvatarDao::StatEntry::operator =(const AvatarDao::StatEntry & other)
{
  return *new (this) StatEntry(other);
}

const QString & AvatarDao::StatEntry::name() const
{
  return m_name;
}

const QString &AvatarDao::StatEntry::value() const
{
  return m_value;
}
