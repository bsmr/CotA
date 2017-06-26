#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QDir>
#include <QMainWindow>
#include <QSettings>

#include "AvatarDao.h"

class QLabel;

namespace Ui
{
  class MainWindow;
}

class MainWindow: public QMainWindow
{
  class ItemBrushes
  {
    enum {
      heavyAlpha = 255,
      mediumAlpha = 207,
      lightAlpha = 159,
    };

    QBrush m_heavy;
    QBrush m_medium;
    QBrush m_light;

  public:
    ItemBrushes();

    const QBrush & heavy() const;
    const QBrush & medium() const;
    const QBrush & light() const;

    void reset();
  };

  static const QString ms_folderEntry;
  static const QString ms_avatarEntry;
  static const QString ms_enableSortEntry;
  static const QString ms_sortColumnEntry;
  static const QString ms_sortOrderEntry;

  QScopedPointer<Ui::MainWindow> m_ui;
  QLabel * m_statusLabel{nullptr};

  ItemBrushes m_itemBrushes;

  QSettings m_settings;
  QString m_avatar;

  AvatarDao m_dao;

  QMetaObject::Connection m_sortIndicatorConnection;
  int m_sortColumn{0};
  int m_sortOrder{0};

  void _updateSortSettings(int column, int order);
  void _refreshAvatars(const QString & logFolder);
  void _refreshDates(const QString & avatar);
  void _refreshStats(const QString & avatar, const QString & date, const QString & filter = {});

public:
  explicit MainWindow(QWidget * parent = nullptr);
  ~MainWindow();
};

#endif // MAINWINDOW_H
