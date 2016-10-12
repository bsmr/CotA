#include "MainWindow.h"
#include <QApplication>

int main(int argc, char *argv[])
{
  QApplication application(argc, argv);
  application.setApplicationVersion(QStringLiteral(APP_VERSION));

  MainWindow window;
  window.show();

  return application.exec();
}
