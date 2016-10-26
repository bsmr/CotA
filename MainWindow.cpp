#include "MainWindow.h"
#include "NotesDialog.h"
#include "ui_MainWindow.h"
#include <QFileDialog>
#include <QInputDialog>
#include <QLabel>
#include <QMessageBox>

/* -----{ MainWindow::ItemBrushes }----- */

MainWindow::ItemBrushes::ItemBrushes()
{
  this->reset();
}

const QBrush& MainWindow::ItemBrushes::heavy() const
{
  return m_heavy;
}

const QBrush& MainWindow::ItemBrushes::medium() const
{
  return m_medium;
}

const QBrush& MainWindow::ItemBrushes::light() const
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

MainWindow::MainWindow(QWidget *parent):
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

  // Set the directory search parameters so that the most recent log files are found first.
  m_logDir.setFilter(QDir::Files);
  m_logDir.setSorting(QDir::Name | QDir::Reversed);

#if defined(Q_OS_LINUX) || defined(Q_OS_OSX)
  const QString defaultFolder = QDir::homePath() + QStringLiteral("/.config/Portalarium/Shroud of the Avatar/ChatLogs");
#elif defined(Q_OS_WIN32)
  const QString defaultFolder = QDir::homePath() + QStringLiteral("/AppData/Roaming/Portalarium/Shroud of the Avatar/ChatLogs");
#else
  const QString defaultFolder;
#endif

  // Get the settings before connecting to any signals.
  const QString folder = m_settings.value(ms_folderEntry, defaultFolder).toString();
  if (folder.isEmpty())
    m_statusLabel->setText(tr("Chat log folder not set."));
  else
  {
    m_logDir.setPath(folder);
    this->_refreshAvatars(folder);

    const QString avatarName = m_settings.value(ms_avatarEntry).toString();
    if (!avatarName.isEmpty())
    {
      m_ui->comboBox->setCurrentText(avatarName);
      if (m_ui->comboBox->currentText() == avatarName)
      {
        m_avatar = avatarName;
        this->_refreshStats(m_ui->comboBox->currentText());
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
    m_sortIndicatorConnection = QObject::connect(m_ui->treeWidget->header(), &QHeaderView::sortIndicatorChanged, [this](int column, Qt::SortOrder order)
    {
      this->_updateSortSettings(column, int(order));
    });
  }

  // Connect the changed signal of the avatar name combo-box.
  QObject::connect(m_ui->comboBox, &QComboBox::currentTextChanged, [this](const QString &text)
  {
    this->_refreshStats(text);
  });

  // Connect the select folder action.
  QObject::connect(m_ui->actionSelectFolder, &QAction::triggered, [this](bool)
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
        this->_refreshAvatars(folders.takeFirst());
    }
  });

  // Connect the note button signal.
  QObject::connect(m_ui->notesButton, &QAbstractButton::clicked, [this](bool)
  {
    auto avatar = m_ui->comboBox->currentText();
    if (avatar.isEmpty())
      return;

    NotesDialog notesDialog(this, tr("Notes for %1").arg(avatar), m_settings.value(avatar).toString());
    if (notesDialog.exec() == QDialog::Accepted)
      m_settings.setValue(avatar, notesDialog.text());
  });

  // Connect the reset action.
  QObject::connect(m_ui->actionResetView, &QAction::triggered, [this](bool)
  {
    this->_refreshAvatars(m_logDir.path());
  });

  // Connect the refresh action.
  QObject::connect(m_ui->actionRefreshStats, &QAction::triggered, [this](bool)
  {
    this->_refreshStats(m_ui->comboBox->currentText());
  });

  // Connect the enable sort action.
  QObject::connect(m_ui->actionEnableSort, &QAction::triggered, [this](bool checked)
  {
    // Disconnect the previous header indicator connection to prevent it from being called when sorting is enabled.
    if (m_sortIndicatorConnection)
      QObject::disconnect(m_sortIndicatorConnection);

    m_settings.setValue(ms_enableSortEntry, checked);
    m_ui->treeWidget->setSortingEnabled(checked);
    if (checked)
    {
      // Sort the items.
      m_ui->treeWidget->sortItems(m_sortColumn, Qt::SortOrder(m_sortOrder));

      // Connect the header indicator signal.
      m_sortIndicatorConnection = QObject::connect(m_ui->treeWidget->header(), &QHeaderView::sortIndicatorChanged, [this](int column, Qt::SortOrder order)
      {
        this->_updateSortSettings(column, int(order));
      });
    }
    else
    {
      // Refresh the stats to get back to the default, unsorted view.
      this->_refreshStats(m_ui->comboBox->currentText());
    }
  });

  // Connect the filter action.
  QObject::connect(m_ui->actionFilter, &QAction::triggered, [this](bool)
  {
    QString filter = QInputDialog::getText(this, tr("Filter Stats"), tr("Text:"));
    if (!filter.isEmpty())
      this->_refreshStats(m_ui->comboBox->currentText(), filter);
  });

  // Connect the about action.
  QObject::connect(m_ui->actionAbout, &QAction::triggered, [this](bool)
  {
    auto title = tr("About %1").arg(this->windowTitle());
    auto message = tr("%1 version %2\nWritten and maintained by Barugon").arg(QApplication::applicationName(), QApplication::applicationVersion());
    QMessageBox::about(this, title, message);
  });

  // Connect to the applications palette changed signal to detect theme changes.
  QObject::connect(static_cast<QGuiApplication*>(QApplication::instance()), &QGuiApplication::paletteChanged, [this](const QPalette&)
  {
    m_itemBrushes.reset();
    this->_refreshStats(m_ui->comboBox->currentText());
  });
}

MainWindow::~MainWindow()
{
}

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

void MainWindow::_refreshAvatars(const QString &folder)
{
  if (m_logDir.path() != folder)
  {
    m_settings.setValue(ms_folderEntry, folder);
    m_logDir.setPath(folder);
  }

  // Clear out the avatar names.
  m_ui->comboBox->clear();

  // Get a list of the log files ("\?" is used here to avoid warnings about trigraphs).
  auto fileInfoList = m_logDir.entryInfoList({QStringLiteral("SotAChatLog_*_???\?-?\?-??.txt")});
  if (fileInfoList.isEmpty())
  {
    m_statusLabel->setText(tr("No log files found."));
    return;
  }

  static const QString startText = QStringLiteral("SotAChatLog_");
  QSet<QString> nameSet;

  // Extract the avatar names.
  for (const auto &fileInfo: fileInfoList)
  {
    QString name = fileInfo.baseName();
    int pos = name.lastIndexOf(QChar('_'));
    if (pos <= startText.length())
      continue;

    name = name.mid(startText.length(), pos - startText.length());
    if (name.isEmpty())
      continue;

    // Replace underscores with spaces and add the name to the set.
    nameSet.insert(name.replace(QChar('_'), QChar(' ')));
  }

  if (nameSet.empty())
  {
    m_statusLabel->setText(tr("No avatars found."));
    return;
  }

  // Sort the names.
  QStringList nameList;
  for (const auto &name: nameSet)
    nameList.append(name);
  nameList.sort();

  // Add the names to the combo box.
  m_ui->comboBox->addItems(nameList);
  m_ui->comboBox->setCurrentIndex(-1);
}

void MainWindow::_refreshStats(const QString &avatarName, const QString &filter)
{
  if (m_avatar != avatarName)
  {
    m_settings.setValue(ms_avatarEntry, avatarName);
    m_avatar = avatarName;
  }

  // Clear out the stats.
  m_ui->treeWidget->clear();

  if (avatarName.isEmpty())
  {
    m_statusLabel->clear();
    m_ui->notesButton->setEnabled(false);
    return;
  }

  m_ui->notesButton->setEnabled(true);

  // Get a list of log files that match the avatar's name ("\?" is used here to avoid warnings about trigraphs).
  const auto fileInfoList = m_logDir.entryInfoList({QStringLiteral("SotAChatLog_%1_???\?-?\?-??.txt").arg(QString(avatarName).replace(QChar(' '), QChar('_')))});
  if (fileInfoList.isEmpty())
  {
    m_statusLabel->setText(tr("No log files found for %1.").arg(avatarName));
    return;
  }

  for (auto &fileInfo: fileInfoList)
  {
    // Attempt to open the log file.
    QFile file(fileInfo.filePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
      continue;

    QByteArray stats;
    QString dateTime;

    // Search for the last "/stats" entry.
    while (!file.atEnd())
    {
      const QByteArray line = file.readLine();
      int pos = line.indexOf("AdventurerLevel:");
      if (pos > 0)
      {
        // In case AdventurerLevel is not the first item....
        pos = line.indexOf("] ");
        if (!(pos > 0))
          continue;

        stats = line.mid(pos + 2);
        dateTime = line.mid(1, pos - 1);
      }
    }

    if (stats.isEmpty())
      continue;

    // Split the text at spaces.
    auto fields = stats.split(' ');

    // Create a collection of text/value pair items.
    QMap<int, QList<QTreeWidgetItem*>> items;
    while (fields.size() >= 2)
    {
      static const QHash<QString, int> order = {
        {QStringLiteral("AdventurerLevel:"), 0},
        {QStringLiteral("ProducerLevel:"), 1},
        {QStringLiteral("VirtueCourage:"), -1},
        {QStringLiteral("VirtueLove:"), -1},
        {QStringLiteral("VirtueTruth:"), -1}
      };

      const QString text = fields.takeFirst();
      const QString value = fields.takeFirst();

      bool searched = false;
      if (!filter.isEmpty())
      {
        searched = text.contains(filter, Qt::CaseInsensitive);
        if (!searched)
          continue;
      }

      QScopedPointer<QTreeWidgetItem> item(new QTreeWidgetItem({text, value}));
      auto iter = order.find(text);

      if (iter != order.end())
      {
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

    m_statusLabel->setText(tr("Showing stats for %1 from %2.").arg(avatarName, dateTime));
    return;
  }

  m_statusLabel->setText(tr("No \"/stats\" found for %1.").arg(avatarName));
}
