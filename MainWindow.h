#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QDir>
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
  const static QString ms_dirEntry;
  const static QString ms_avatarEntry;
  const static QString ms_enableSortEntry;
  const static QString ms_sortColumnEntry;
  const static QString ms_sortOrderEntry;

  Ui::MainWindow *m_ui;
  QSettings m_settings;
  QString m_avatar;
  QDir m_logDir;
  int m_sortColumn{0};
  int m_sortOrder{0};

  void _refreshAvatars(const QString &directory);
  void _refreshStats(const QString &avatarName);
};

#endif // MAINWINDOW_H
