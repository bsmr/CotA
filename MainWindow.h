#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QDir>
#include <QLabel>
#include <QMainWindow>
#include <QSettings>

namespace Ui
{
  class MainWindow;
}

class MainWindow: public QMainWindow
{
  Q_OBJECT

public:
  explicit MainWindow(QWidget *parent = 0);
  ~MainWindow();

private:
  static const QString ms_folderEntry;
  static const QString ms_avatarEntry;
  static const QString ms_enableSortEntry;
  static const QString ms_sortColumnEntry;
  static const QString ms_sortOrderEntry;

  Ui::MainWindow *m_ui;
  QLabel *m_statusLabel;
  QSettings m_settings;
  QString m_avatar;
  QDir m_logDir;
  QMetaObject::Connection m_sortIndicatorConnetion;
  int m_sortColumn{0};
  int m_sortOrder{0};

  void _updateSortSettings(int column, int order);
  void _refreshAvatars(const QString &folder);
  void _refreshStats(const QString &avatarName);
};

#endif // MAINWINDOW_H
