#ifndef NOTESDIALOG_H
#define NOTESDIALOG_H

#include <QDialog>

namespace Ui {
  class NotesDialog;
}

class NotesDialog: public QDialog
{
public:
  explicit NotesDialog(QWidget *parent, const QString &title, const QString &text);
  ~NotesDialog();

  QString text() const;

protected:
  void showEvent(QShowEvent*) override;

private:
  QScopedPointer<Ui::NotesDialog> m_ui;
};

#endif // NOTESDIALOG_H
