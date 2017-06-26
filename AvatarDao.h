#ifndef AVATARDAO_H
#define AVATARDAO_H

#include <QDir>
#include <QList>
#include <QString>
#include <QStringList>

class AvatarDao
{
  static bool _preParse(const QByteArray & line, QByteArray & date, QByteArray & stats);

  const QDir m_logDir;

  QFileInfoList _getFileinfoList(const QString & avatar = {}) const;

public:
  class StatEntry
  {
    const QString m_name;
    const QString m_value;

  public:
    StatEntry();
    StatEntry(const QString & name, const QString & value);
    StatEntry(const StatEntry & other);

    StatEntry & operator =(const StatEntry & other);

    const QString & name() const;
    const QString & value() const;
  };

  AvatarDao();
  AvatarDao(const QString & logFolder);
  AvatarDao(const AvatarDao & other);

  AvatarDao & operator =(const AvatarDao & other);

  QString path() const;

  QStringList getAvatars() const;
  QStringList getStatDates(const QString & avatar) const;
  QList<StatEntry> getStats(const QString & avatar, const QString & date) const;
};

#endif // AVATARDAO_H
