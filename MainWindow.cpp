#include "MainWindow.h"
#include "ui_MainWindow.h"
#include <QFileDialog>

const QString MainWindow::ms_dirEntry = QStringLiteral("logDir");
const QString MainWindow::ms_avatarEntry = QStringLiteral("avatar");

MainWindow::MainWindow(QWidget *parent):
  QMainWindow(parent),
  m_ui(new Ui::MainWindow),
  m_settings(QStringLiteral("dotborg"), QStringLiteral("Companion of the Avatar"))
{
  m_ui->setupUi(this);

  // Set the tree-view header so that it will resize to the contents.
  m_ui->treeWidget->header()->setSectionResizeMode(0, QHeaderView::ResizeToContents);
  m_ui->treeWidget->header()->setSectionResizeMode(1, QHeaderView::ResizeToContents);

  m_logDir.setFilter(QDir::Files);
  m_logDir.setSorting(QDir::Name | QDir::Reversed);

  // Get the settings before hooking up the actions.
  QString directory = m_settings.value(ms_dirEntry).toString();
  if (directory.isEmpty())
    m_ui->statusBar->showMessage(QStringLiteral("Chat log directory not set."));
  else
  {
    this->_refreshAvatars(directory);

    QString avatarName = m_settings.value(ms_avatarEntry).toString();
    if (!avatarName.isEmpty())
    {
      m_ui->comboBox->setCurrentText(avatarName);
      this->_refreshStats(m_ui->comboBox->currentText());
    }
  }

  // Connect the changed signal of the avatar name combo-box.
  connect(m_ui->comboBox, &QComboBox::currentTextChanged, [this](const QString &avatarName)
  {
    this->_refreshStats(avatarName);
  });

  // Connect the select folder action.
  connect(m_ui->actionSelectDirectory, &QAction::triggered, [this](bool)
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
  connect(m_ui->actionRefresh, &QAction::triggered, [this](bool)
  {
    this->_refreshStats(m_ui->comboBox->currentText());
  });
}

MainWindow::~MainWindow()
{
  delete m_ui;
}

void MainWindow::_refreshAvatars(const QString &directory)
{
  m_settings.setValue(ms_dirEntry, directory);

  // Clear out the avatar names.
  m_ui->comboBox->clear();

  // Get a list of the log files.
  m_logDir.setPath(directory);
  auto fileInfoList = m_logDir.entryInfoList({QStringLiteral("*.txt")});
  if (fileInfoList.isEmpty())
  {
    m_ui->statusBar->showMessage(QStringLiteral("No log files found."));
    return;
  }

  const static QString startText = QStringLiteral("SotAChatLog_");
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
    nameSet.insert(name.replace('_', ' '));
  }

  if (nameSet.empty())
  {
    m_ui->statusBar->showMessage(QStringLiteral("No log files found."));
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
  m_settings.setValue(ms_avatarEntry, avatarName);

  // Clear out the stats.
  m_ui->treeWidget->clear();
  if (avatarName.isEmpty())
    return;

  // Get a list of log files that match the avatar's name.
  auto fileInfoList = m_logDir.entryInfoList({QStringLiteral("*%1*.txt").arg(avatarName)});
  if (fileInfoList.isEmpty())
  {
    m_ui->statusBar->showMessage(QStringLiteral("No log files found for %1.").arg(avatarName));
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
      if (pos == 24)
      {
        dateTime = line.mid(1, 21);
        stats = line.mid(pos);
      }
    }

    if (!stats.isEmpty())
    {
      // Split the text at spaces.
      auto fields = stats.split(' ');

      // Create a list of text/value pair items;
      QList<QTreeWidgetItem*> items;
      while (fields.size() >= 2)
      {
        QString text = fields.takeFirst();
        QString value = fields.takeFirst();
        items.append(new QTreeWidgetItem({text, value}));
      }

      // Insert the items into the tree.
      m_ui->treeWidget->insertTopLevelItems(0, items);

      // The log files are searched in reverse order (newest first), so we're done.
      m_ui->statusBar->showMessage(QStringLiteral("Showing stats for %1 from %2.").arg(avatarName).arg(dateTime));
      return;
    }
  }

  m_ui->statusBar->showMessage(QStringLiteral("No \"/stats\" found for %1.").arg(avatarName));
}
