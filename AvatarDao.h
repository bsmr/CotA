#ifndef AVATARDAO_H
#define AVATARDAO_H

#include <QDir>
#include <QStringList>

class AvatarDao
{
  static const QByteArray ms_adventurerLevel;

  static QByteArray _getDate(const QByteArray & line, const QByteArray & search);
  static QByteArray _getText(const QByteArray & line, const QByteArray & date, const QByteArray & search);

  const QDir m_logDir;
  QFileInfoList _getFileinfoList(const QString & avatar = {}) const;

public:
  class StatItem
  {
    const QString m_name;
    const QString m_value;

  public:
    StatItem();
    StatItem(const QString & name, const QString & value);
    StatItem(const StatItem & other);

    StatItem & operator =(const StatItem & other);

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
  QList<StatItem> getStats(const QString & avatar, const QString & date) const;
};

#endif // AVATARDAO_H
