#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QDir>
#include <QMainWindow>
#include <QSettings>

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

    const QBrush& heavy() const;
    const QBrush& medium() const;
    const QBrush& light() const;

    void reset();
  };

  static const QString ms_folderEntry;
  static const QString ms_avatarEntry;
  static const QString ms_enableSortEntry;
  static const QString ms_sortColumnEntry;
  static const QString ms_sortOrderEntry;

  QScopedPointer<Ui::MainWindow> m_ui;
  QLabel *m_statusLabel {nullptr};

  ItemBrushes m_itemBrushes;
  QSettings m_settings;
  QString m_avatar;
  QDir m_logDir;

  QMetaObject::Connection m_sortIndicatorConnetion;
  int m_sortColumn {0};
  int m_sortOrder {0};

public:
  explicit MainWindow(QWidget *parent = nullptr);
  ~MainWindow();

private:
  void _updateSortSettings(int column, int order);
  void _refreshAvatars(const QString &folder);
  void _refreshStats(const QString &avatarName, const QString &filter = {});
};

#endif // MAINWINDOW_H
