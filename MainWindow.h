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
  explicit MainWindow(QWidget *parent = nullptr);
  ~MainWindow();

private:
  class Brushes
  {
    enum {
      heavyAlpha = 255,
      mediumAlpha = 207,
      lightAlpha = 159,
    };

    mutable QBrush m_heavy;
    mutable QBrush m_medium;
    mutable QBrush m_light;

  public:
    Brushes();

    Brushes(const Brushes&) = delete;
    const Brushes& operator =(const Brushes&) = delete;

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

  Ui::MainWindow *m_ui{nullptr};
  QLabel *m_statusLabel{nullptr};

  Brushes m_itemBrushes;
  QSettings m_settings;
  QString m_avatar;
  QDir m_logDir;

  QMetaObject::Connection m_sortIndicatorConnetion;
  int m_sortColumn{0};
  int m_sortOrder{0};

  void _updateSortSettings(int column, int order);
  void _refreshAvatars(const QString &folder);
  void _refreshStats(const QString &avatarName, const QString &filter = {});
};

#endif // MAINWINDOW_H
