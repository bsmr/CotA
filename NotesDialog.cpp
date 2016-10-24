#include "NotesDialog.h"
#include "ui_NotesDialog.h"

NotesDialog::NotesDialog(QWidget *parent, const QString &title, const QString &text):
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
