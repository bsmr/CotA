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

  Ui::MainWindow *m_ui;
  QSettings m_settings;
  QDir m_logDir;

  void _refreshAvatars(const QString &directory);
  void _refreshStats(const QString &avatarName);
};

#endif // MAINWINDOW_H
