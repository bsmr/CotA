#include "MainWindow.h"
#include "ui_MainWindow.h"
#include <QFileDialog>

const QString MainWindow::ms_dirEntry = QStringLiteral("logDir");
const QString MainWindow::ms_avatarEntry = QStringLiteral("avatar");
const QString MainWindow::ms_enableSortEntry = QStringLiteral("enableSort");
const QString MainWindow::ms_sortColumnEntry = QStringLiteral("sortColumn");
const QString MainWindow::ms_sortOrderEntry = QStringLiteral("sortOrder");

MainWindow::MainWindow(QWidget *parent):
  QMainWindow(parent),
  m_ui(new Ui::MainWindow),
  m_statusLabel(new QLabel),
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

#if defined(Q_OS_LINUX)
  const QString defaultDirectory = QDir::homePath() + QStringLiteral("/.config/Portalarium/Shroud of the Avatar/ChatLogs");
#elif defined(Q_OS_OSX)
  // I'm guessing that OS X is the same as Linux, which is probably wrong.
  const QString defaultDirectory = QDir::homePath() + QStringLiteral("/.config/Portalarium/Shroud of the Avatar/ChatLogs");
#elif defined(Q_OS_WIN32)
  // Here's a guess at Windows.
  const QString defaultDirectory = QDir::homePath() + QStringLiteral("/AppData/Roaming/Portalarium/Shroud of the Avatar/ChatLogs");
#else
# error "You are attempting to compile CotA for a platform that SotA does not run on."
#endif

  // Get the settings before connecting to any signals.
  const QString directory = m_settings.value(ms_dirEntry, defaultDirectory).toString();
  if (directory.isEmpty())
    m_statusLabel->setText(QStringLiteral("Chat log directory not set."));
  else
  {
    m_logDir.setPath(directory);
    this->_refreshAvatars(directory);

    const QString avatarName = m_settings.value(ms_avatarEntry).toString();
    if (!avatarName.isEmpty())
    {
      m_avatar = avatarName;
      m_ui->comboBox->setCurrentText(avatarName);
      this->_refreshStats(m_ui->comboBox->currentText());
    }
  }

  m_sortColumn = m_settings.value(ms_sortColumnEntry).toInt();
  m_sortOrder = m_settings.value(ms_sortOrderEntry).toInt();
  if (m_settings.value(ms_enableSortEntry).toBool())
  {
    m_ui->actionEnableSort->setChecked(true);
    m_ui->treeWidget->setSortingEnabled(true);
    m_ui->treeWidget->sortItems(m_sortColumn, Qt::SortOrder(m_sortOrder));
    m_sortIndicatorConnetion = QObject::connect(m_ui->treeWidget->header(), &QHeaderView::sortIndicatorChanged, [this](int column, Qt::SortOrder order)
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
  QObject::connect(m_ui->actionSelectDirectory, &QAction::triggered, [this](bool)
  {
    QFileDialog directorySelect(this);
    directorySelect.setFileMode(QFileDialog::Directory);
    directorySelect.setOption(QFileDialog::ShowDirsOnly, true);
    directorySelect.setFilter(QDir::Dirs | QDir::Hidden | QDir::NoDotAndDotDot);
    directorySelect.setDirectory(QDir::homePath());
    if (directorySelect.exec())
    {
      QStringList directories = directorySelect.selectedFiles();
      if (!directories.isEmpty())
        this->_refreshAvatars(directories.takeFirst());
    }
  });

  // Connect the refresh action.
  QObject::connect(m_ui->actionRefresh, &QAction::triggered, [this](bool)
  {
    this->_refreshStats(m_ui->comboBox->currentText());
  });

  // Connect the enable sort action.
  QObject::connect(m_ui->actionEnableSort, &QAction::triggered, [this](bool checked)
  {
    // Disconnect the previous header indicator connection to prevent it from being called when sorting is enabled.
    if (m_sortIndicatorConnetion)
      QObject::disconnect(m_sortIndicatorConnetion);

    m_settings.setValue(ms_enableSortEntry, checked);
    m_ui->treeWidget->setSortingEnabled(checked);
    if (checked)
    {
      // Sort the items.
      m_ui->treeWidget->sortItems(m_sortColumn, Qt::SortOrder(m_sortOrder));

      // Connect the header indicator signal.
      m_sortIndicatorConnetion = QObject::connect(m_ui->treeWidget->header(), &QHeaderView::sortIndicatorChanged, [this](int column, Qt::SortOrder order)
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
}

MainWindow::~MainWindow()
{
  delete m_ui;
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

void MainWindow::_refreshAvatars(const QString &directory)
{
  if (m_logDir.path() != directory)
  {
    m_settings.setValue(ms_dirEntry, directory);
    m_logDir.setPath(directory);
  }

  // Clear out the avatar names.
  m_ui->comboBox->clear();

  // Get a list of the log files ("\?" is used here to avoid warnings about trigraphs).
  auto fileInfoList = m_logDir.entryInfoList({QStringLiteral("SotAChatLog_*_???\?-?\?-??.txt")});
  if (fileInfoList.isEmpty())
  {
    m_statusLabel->setText(QStringLiteral("No log files found."));
    return;
  }

  static const QString startText = QStringLiteral("SotAChatLog_");
  QSet<QString> nameSet;

  // Get the avatar names.
  for (auto& fileInfo: fileInfoList)
  {
    QString name = fileInfo.baseName();
    if (!name.startsWith(startText))
      continue;

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
    m_statusLabel->setText(QStringLiteral("No log files found."));
    return;
  }

  // Sort the names.
  QStringList nameList;
  for (auto& name: nameSet)
    nameList.append(name);
  nameList.sort();

  // Add the names to the combo box.
  m_ui->comboBox->addItems(nameList);
  m_ui->comboBox->setCurrentIndex(-1);
}

void MainWindow::_refreshStats(const QString &avatarName)
{
  if (m_avatar != avatarName)
  {
    m_settings.setValue(ms_avatarEntry, avatarName);
    m_avatar = avatarName;
  }

  // Clear out the stats.
  m_ui->treeWidget->clear();
  if (avatarName.isEmpty())
    return;

  // Get a list of log files that match the avatar's name ("\?" is used here to avoid warnings about trigraphs).
  auto fileInfoList = m_logDir.entryInfoList({QStringLiteral("SotAChatLog_%1_???\?-?\?-??.txt").arg(QString(avatarName).replace(QChar(' '), QChar('_')))});
  if (fileInfoList.isEmpty())
  {
    m_statusLabel->setText(QStringLiteral("No log files found for %1.").arg(avatarName));
    return;
  }

  for (auto& fileInfo: fileInfoList)
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
      QByteArray line = file.readLine();
      int pos = line.indexOf("AdventurerLevel:");
      if (pos > 0)
      {
        stats = line.mid(pos);
        dateTime = line.mid(1, pos - 3);
      }
    }

    if (!stats.isEmpty())
    {
      // Split the text at spaces.
      auto fields = stats.split(' ');

      // Create a collection of text/value pair items.
      QMap<int, QList<QTreeWidgetItem*>> items;
      while (fields.size() >= 2)
      {
        static const QBrush blackBrush(QColor(0, 0, 0, 255));
        static const QBrush grayBrush(QColor(96, 96, 96, 255));
        static const QBrush blueBrush(QColor(0, 0, 128, 255));
        static const QBrush redBrush(QColor(128, 0, 0, 255));

        static const QHash<QString, int> order = {
          {QStringLiteral("AdventurerLevel:"), 0},
          {QStringLiteral("ProducerLevel:"), 0},
          {QStringLiteral("VirtueCourage:"), 1},
          {QStringLiteral("VirtueLove:"), 1},
          {QStringLiteral("VirtueTruth:"), 1}
        };

        QString text = fields.takeFirst();
        QString value = fields.takeFirst();

        auto item = new QTreeWidgetItem({text, value});
        auto iter = order.find(text);

        if (iter != order.end())
        {
          switch (iter.value())
          {
            case 0:
              // Use a black brush for AdventurerLevel and ProducerLevel.
              item->setForeground(0, blackBrush);
              item->setForeground(1, blackBrush);
              break;

            case 1:
            {
              const int virtueValue = value.toInt();

              item->setForeground(0, grayBrush);
              if (virtueValue > 0)
              {
                // The virtue value is greater than 0, so color it blue.
                item->setForeground(1, blueBrush);
              }
              else if (virtueValue < 0)
              {
                // The virtue value is less than 0, so color it red.
                item->setForeground(1, redBrush);
              }
              else
                item->setForeground(1, grayBrush);

              break;
            }

            default:
              item->setForeground(0, grayBrush);
              item->setForeground(1, grayBrush);
              break;
          }

          items[iter.value()].append(item);
        }
        else
        {
          // Fields not specifically in the ordering collection are put at the end.
          item->setForeground(0, grayBrush);
          item->setForeground(1, grayBrush);
          items[std::numeric_limits<int>::max()].append(item);
        }
      }

      // Add the items to the tree.
      for (auto iter = items.begin(); iter != items.end(); ++iter)
        m_ui->treeWidget->addTopLevelItems(iter.value());

      m_statusLabel->setText(QStringLiteral("Showing stats for %1 from %2.").arg(avatarName).arg(dateTime));
      return;
    }
  }

  m_statusLabel->setText(QStringLiteral("No \"/stats\" found for %1.").arg(avatarName));
}
