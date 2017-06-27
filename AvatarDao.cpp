#include "AvatarDao.h"

#include <QSet>

// -----{ AvatarDao }----- //

const QByteArray AvatarDao::ms_adventurerLevel("AdventurerLevel:");

QByteArray AvatarDao::_getDate(const QByteArray & line, const QByteArray & search)
{
  if (line.startsWith('['))
  {
    int searchPos = (search.isEmpty()? line.length(): line.indexOf(search));
    if (searchPos > 0)
    {
      int bracketPos = line.indexOf("] ");
      if ((bracketPos > 1) && (bracketPos < searchPos))
        return line.mid(1, bracketPos - 1);
    }
  }

  return {};
}

QByteArray AvatarDao::_getText(const QByteArray & line, const QByteArray & date, const QByteArray & search)
{
  if (line.startsWith("[" + date + "] ") && (search.isEmpty() || line.contains(search)))
    return line.mid(date.length() + 3);

  return {};
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

AvatarDao & AvatarDao::operator =(const AvatarDao & other)
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

  for (const auto & fileInfo: fileInfoList)
  {
    QString name = fileInfo.baseName();
    int pos = name.lastIndexOf(QChar('_'));
    if (!(pos > startText.length()))
      continue;

    // Extract the avatar name.
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
      QByteArray date = _getDate(file.readLine(), ms_adventurerLevel);
      if (!date.isEmpty())
         dates.append(date);
    }
  }

  return dates;
}

QList<AvatarDao::StatItem> AvatarDao::getStats(const QString & avatar, const QString & date) const
{
  auto fileInfoList = _getFileinfoList(avatar);
  if (fileInfoList.isEmpty())
    return {};

  const QByteArray dateCheck = date.toUtf8();
  for (auto &fileInfo: fileInfoList)
  {
    // Attempt to open the log file.
    QFile file(fileInfo.filePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
      continue;

    // Search for the "/stats" entry that matches dateTime.
    QByteArray stats;
    while (!file.atEnd())
    {
      stats = _getText(file.readLine(), dateCheck, ms_adventurerLevel);
      if (!stats.isEmpty())
        break;
    }

    if (stats.isEmpty())
      continue;

    // Split the text at spaces.
    auto fields = stats.split(' ');
    fields.removeAll({});

    // Create a collection of StatEntry items.
    QList<StatItem> items;
    while (fields.size() >= 2)
    {
      const QString name = fields.takeFirst();
      if (name.endsWith(':'))
        items.append(StatItem(name.left(name.length() - 1), fields.takeFirst()));
    }

    return items;
  }

  return {};
}

// -----{ AvatarDao::StatItem }----- //

AvatarDao::StatItem::StatItem()
{
}

AvatarDao::StatItem::StatItem(const QString & name, const QString & value):
  m_name(name),
  m_value(value)
{
}

AvatarDao::StatItem::StatItem(const AvatarDao::StatItem & other):
  m_name(other.m_name),
  m_value(other.m_value)
{
}

AvatarDao::StatItem & AvatarDao::StatItem::operator =(const AvatarDao::StatItem & other)
{
  return *new (this) StatItem(other);
}

const QString & AvatarDao::StatItem::name() const
{
  return m_name;
}

const QString &AvatarDao::StatItem::value() const
{
  return m_value;
}
