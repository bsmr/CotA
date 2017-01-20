#include "NotesDialog.h"
#include "ui_NotesDialog.h"

NotesDialog::NotesDialog(QWidget * parent, const QString & title, const QString & text):
  QDialog(parent),
  m_ui(new Ui::NotesDialog)
{
  m_ui->setupUi(this);
  m_ui->plainTextEdit->setPlainText(text);
  this->setWindowTitle(title);
}

QString NotesDialog::text() const
{
  return m_ui->plainTextEdit->toPlainText();
}

NotesDialog::~NotesDialog()
{
}

void NotesDialog::showEvent(QShowEvent * /*event*/)
{
  // Reposition the dialog so that it's centered on the main window.
  auto parent = this->parentWidget();
  if (parent)
    this->move(parent->x() + (parent->width() - this->width()) / 2, parent->y() + (parent->height() - this->height()) / 2);
}
