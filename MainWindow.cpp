#include "MainWindow.h"
#include "NotesDialog.h"
#include "ui_MainWindow.h"

#include <QFileDialog>
#include <QInputDialog>
#include <QMessageBox>

/* -----{ MainWindow::ItemBrushes }----- */

MainWindow::ItemBrushes::ItemBrushes()
{
  reset();
}

const QBrush & MainWindow::ItemBrushes::heavy() const
{
  return m_heavy;
}

const QBrush & MainWindow::ItemBrushes::medium() const
{
  return m_medium;
}

const QBrush & MainWindow::ItemBrushes::light() const
{
  return m_light;
}

void MainWindow::ItemBrushes::reset()
{
  QScopedPointer<QTreeWidgetItem> item(new QTreeWidgetItem());
  auto color = item->foreground(0).color();

  m_heavy = QBrush(QColor(color.red(), color.green(), color.blue(), heavyAlpha));
  m_medium = QBrush(QColor(color.red(), color.green(), color.blue(), mediumAlpha));
  m_light = QBrush(QColor(color.red(), color.green(), color.blue(), lightAlpha));
}

/* -----{ MainWindow }----- */

const QString MainWindow::ms_folderEntry(QStringLiteral("logFolder"));
const QString MainWindow::ms_avatarEntry(QStringLiteral("avatar"));
const QString MainWindow::ms_enableSortEntry(QStringLiteral("enableSort"));
const QString MainWindow::ms_sortColumnEntry(QStringLiteral("sortColumn"));
const QString MainWindow::ms_sortOrderEntry(QStringLiteral("sortOrder"));

void MainWindow::_updateSortSettings(int column, int order)
{
  if (m_sortColumn != column)
  {
    m_sortColumn = column;
    m_settings.setValue(ms_sortColumnEntry, m_sortColumn);
  }

  if (m_sortOrder != order)
  {
    m_sortOrder = order;
    m_settings.setValue(ms_sortOrderEntry, m_sortOrder);
  }
}

void MainWindow::_refreshAvatars(const QString & logFolder)
{
  if (m_dao.path() != logFolder)
  {
    // Update the settings.
    m_settings.setValue(ms_folderEntry, logFolder);
    m_dao = AvatarDao(logFolder);
  }

  // Clear out the avatar names.
  m_ui->avatarComboBox->clear();

  auto avatars = m_dao.getAvatars();
  if (avatars.isEmpty())
  {
    m_statusLabel->setText(tr("No avatars found."));
    return;
  }

  // Add the avatar names to the combo box.
  avatars.sort();
  m_ui->avatarComboBox->addItems(avatars);
  m_ui->avatarComboBox->setCurrentIndex(-1);
}

void MainWindow::_refreshDates(const QString & avatar, const QString & date)
{
  if (m_avatar != avatar)
  {
    // Update the settings.
    m_settings.setValue(ms_avatarEntry, avatar);
    m_avatar = avatar;
  }

  // Clear out the dates.
  m_ui->dateComboBox->clear();

  if (avatar.isEmpty())
  {
    m_statusLabel->clear();
    m_ui->notesButton->setEnabled(false);
    return;
  }

  m_ui->notesButton->setEnabled(true);

  // Get a list of dates where "/stats" was used.
  auto dates = m_dao.getStatDates(avatar);
  if (dates.isEmpty())
  {
    m_statusLabel->setText(tr("No \"/stats\" found for %1.").arg(avatar));
    return;
  }

  // Sort the list so that the most recent stats are first.
  qSort(dates.begin(), dates.end(), [](const QString & s1, const QString & s2)
  {
    return s2 < s1;
  });

  m_ui->dateComboBox->addItems(dates);

  if (!date.isEmpty())
    m_ui->dateComboBox->setCurrentText(date);

  if (m_ui->dateComboBox->currentIndex() < 0)
    m_ui->dateComboBox->setCurrentIndex(0);
}

void MainWindow::_refreshStats(const QString & avatar, const QString & date, const QString & filter)
{
  // Clear out the stats.
  m_ui->treeWidget->clear();

  if (avatar.isEmpty() || date.isEmpty())
    return;

  // Get the stats.
  auto stats = m_dao.getStats(avatar, date);
  if (stats.isEmpty())
  {
    m_statusLabel->setText(tr("No \"/stats\" found for %1 on %2... weird!").arg(avatar, date));
    return;
  }

  QMap<int, QList<QTreeWidgetItem*>> items;
  for (const auto & stat: stats)
  {
    // A hash of prioritized items.
    static const QHash<QString, int> order = {
      {QStringLiteral("AdventurerLevel"), 0},
      {QStringLiteral("ProducerLevel"), 1},
      {QStringLiteral("VirtueCourage"), -1},
      {QStringLiteral("VirtueLove"), -1},
      {QStringLiteral("VirtueTruth"), -1}
    };

    bool searched = false;
    if (!filter.isEmpty())
    {
      searched = stat.name().contains(filter, Qt::CaseInsensitive);
      if (!searched)
        continue;
    }

    QScopedPointer<QTreeWidgetItem> item(new QTreeWidgetItem({stat.name() + ' ', stat.value()}));
    auto iter = order.find(stat.name());

    if (iter != order.end())
    {
      // Colorize the prioritized items.
      switch (iter.value())
      {
        case 0:
          item->setForeground(0, m_itemBrushes.heavy());
          item->setForeground(1, m_itemBrushes.heavy());
          break;

        case 1:
          item->setForeground(0, m_itemBrushes.medium());
          item->setForeground(1, m_itemBrushes.medium());
          break;

        default:
          item->setForeground(0, m_itemBrushes.light());
          item->setForeground(1, m_itemBrushes.light());
          break;
      }

      // Don't show items with negative priority (unless they're explicitly searched for).
      if ((iter.value() >= 0) || searched)
        items[iter.value()].append(item.take());
    }
    else
    {
      item->setForeground(0, m_itemBrushes.light());
      item->setForeground(1, m_itemBrushes.light());

      // Fields not specifically in the ordering collection are put at the end.
      items[std::numeric_limits<int>::max()].append(item.take());
    }
  }

  // Add the items to the tree.
  for (auto iter = items.begin(); iter != items.end(); ++iter)
    m_ui->treeWidget->addTopLevelItems(iter.value());

  m_statusLabel->setText(tr("Showing stats for %1 from %2.").arg(avatar, date));
  return;
}

MainWindow::MainWindow(QWidget * parent):
  QMainWindow(parent),
  m_ui(new Ui::MainWindow),
  m_statusLabel{new QLabel},
  m_settings(QStringLiteral("Barugon"), QStringLiteral("Companion of the Avatar"))
{
  m_ui->setupUi(this);
  m_ui->statusBar->addWidget(m_statusLabel);

  // Set the tree-view header so that it will resize to the contents.
  m_ui->treeWidget->header()->setSectionResizeMode(0, QHeaderView::ResizeToContents);
  m_ui->treeWidget->header()->setSectionResizeMode(1, QHeaderView::ResizeToContents);

  // Add these actions to the main window so that the shortcut keys work.
  addAction(m_ui->actionQuit);
  addAction(m_ui->actionRefreshStats);
  addAction(m_ui->actionFilter);

#if defined(Q_OS_LINUX) || defined(Q_OS_OSX)
  const QString defaultFolder = QDir::homePath() + QStringLiteral("/.config/Portalarium/Shroud of the Avatar/ChatLogs");
#elif defined(Q_OS_WIN32)
  const QString defaultFolder = QDir::homePath() + QStringLiteral("/AppData/Roaming/Portalarium/Shroud of the Avatar/ChatLogs");
#else
  const QString defaultFolder;
#endif

  // Get the settings before connecting to any signals.
  const QString logFolder = m_settings.value(ms_folderEntry, defaultFolder).toString();
  if (logFolder.isEmpty())
    m_statusLabel->setText(tr("Chat log folder not set."));
  else
  {
    m_dao = AvatarDao(logFolder);
    _refreshAvatars(logFolder);

    if (m_ui->avatarComboBox->count() > 0)
    {
      QString avatarName = m_settings.value(ms_avatarEntry).toString();
      if (!avatarName.isEmpty())
        m_ui->avatarComboBox->setCurrentText(avatarName);

      if (m_ui->avatarComboBox->currentIndex() < 0)
      {
        m_ui->avatarComboBox->setCurrentIndex(0);
        avatarName = m_ui->avatarComboBox->currentText();
      }

      if (!avatarName.isEmpty())
      {
        m_avatar = avatarName;
        _refreshDates(m_ui->avatarComboBox->currentText());
        _refreshStats(m_ui->avatarComboBox->currentText(), m_ui->dateComboBox->currentText());
      }
    }
  }

  m_sortColumn = m_settings.value(ms_sortColumnEntry).toInt();
  m_sortOrder = m_settings.value(ms_sortOrderEntry).toInt();
  if (m_settings.value(ms_enableSortEntry).toBool())
  {
    m_ui->actionEnableSort->setChecked(true);
    m_ui->treeWidget->setSortingEnabled(true);
    m_ui->treeWidget->sortItems(m_sortColumn, Qt::SortOrder(m_sortOrder));
    m_sortIndicatorConnection = connect(m_ui->treeWidget->header(), &QHeaderView::sortIndicatorChanged, this, [this](int column, Qt::SortOrder order)
    {
      _updateSortSettings(column, int(order));
    });
  }

  // Connect the quit action.
  connect(m_ui->actionQuit, &QAction::triggered, this, [this](bool)
  {
    close();
  });

  // Connect the changed signal of the avatar name combo-box.
  connect(m_ui->avatarComboBox, &QComboBox::currentTextChanged, this, [this](const QString &text)
  {
    _refreshDates(text);
  });

  // Connect the changed signal of the date combo-box.
  connect(m_ui->dateComboBox, &QComboBox::currentTextChanged, this, [this](const QString &text)
  {
    _refreshStats(m_ui->avatarComboBox->currentText(), text);
  });

  // Connect the select folder action.
  connect(m_ui->actionSelectFolder, &QAction::triggered, this, [this](bool)
  {
    QFileDialog folderSelect(this, tr("Select Log Folder"));
    folderSelect.setFileMode(QFileDialog::Directory);
    folderSelect.setOption(QFileDialog::ShowDirsOnly, true);
    folderSelect.setFilter(QDir::Dirs | QDir::Hidden | QDir::NoDotAndDotDot);
    folderSelect.setDirectory(QDir::homePath());
    if (folderSelect.exec())
    {
      QStringList folders = folderSelect.selectedFiles();
      if (!folders.isEmpty())
        _refreshAvatars(folders.takeFirst());
    }
  });

  // Connect the note button signal.
  connect(m_ui->notesButton, &QAbstractButton::clicked, this, [this](bool)
  {
    auto avatar = m_ui->avatarComboBox->currentText();
    if (avatar.isEmpty())
      return;

    NotesDialog notesDialog(this, tr("Notes for %1").arg(avatar), m_settings.value(avatar).toString());
    if (notesDialog.exec() == QDialog::Accepted)
      m_settings.setValue(avatar, notesDialog.text());
  });

  // Connect the reset action.
  connect(m_ui->actionResetView, &QAction::triggered, this, [this](bool)
  {
    _refreshAvatars(m_dao.path());
  });

  // Connect the refresh action.
  connect(m_ui->actionRefreshStats, &QAction::triggered, this, [this](bool)
  {
    _refreshDates(m_ui->avatarComboBox->currentText(), m_ui->dateComboBox->currentText());
  });

  // Connect the enable sort action.
  connect(m_ui->actionEnableSort, &QAction::triggered, this, [this](bool checked)
  {
    // Disconnect the previous header indicator connection to prevent it from being called when sorting is enabled.
    if (m_sortIndicatorConnection)
      disconnect(m_sortIndicatorConnection);

    m_settings.setValue(ms_enableSortEntry, checked);
    m_ui->treeWidget->setSortingEnabled(checked);
    if (checked)
    {
      // Sort the items.
      m_ui->treeWidget->sortItems(m_sortColumn, Qt::SortOrder(m_sortOrder));

      // Connect the header indicator signal.
      m_sortIndicatorConnection = connect(m_ui->treeWidget->header(), &QHeaderView::sortIndicatorChanged, this, [this](int column, Qt::SortOrder order)
      {
        _updateSortSettings(column, int(order));
      });
    }
    else
    {
      // Refresh the stats to get back to the default, unsorted view.
      _refreshStats(m_ui->avatarComboBox->currentText(), m_ui->dateComboBox->currentText());
    }
  });

  // Connect the filter action.
  connect(m_ui->actionFilter, &QAction::triggered, this, [this](bool)
  {
    QString filter = QInputDialog::getText(this, tr("Filter Stats"), tr("Text:"));
    if (!filter.isEmpty())
      _refreshStats(m_ui->avatarComboBox->currentText(), m_ui->dateComboBox->currentText(), filter);
  });

  // Connect the about action.
  connect(m_ui->actionAbout, &QAction::triggered, this, [this](bool)
  {
    auto message = tr("%1 version %2\nWritten and maintained by Barugon").arg(QApplication::applicationName(), QApplication::applicationVersion());
    QMessageBox::about(this, tr("About %1").arg(windowTitle()), message);
  });

  // Connect to the applications palette changed signal to detect theme changes.
  connect(static_cast<QGuiApplication*>(QApplication::instance()), &QGuiApplication::paletteChanged, this, [this](const QPalette&)
  {
    m_itemBrushes.reset();
    _refreshStats(m_ui->avatarComboBox->currentText(), m_ui->dateComboBox->currentText());
  });
}

MainWindow::~MainWindow()
{
}
