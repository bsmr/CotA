#-------------------------------------------------
#
# Project created by QtCreator 2016-09-21T09:44:06
#
#-------------------------------------------------

VERSION = 1.1.0
DEFINES += APP_VERSION=\\\"$$VERSION\\\"

QT += core gui
greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = CotA
TEMPLATE = app

SOURCES += main.cpp \
    MainWindow.cpp \
    NotesDialog.cpp

HEADERS += \
    MainWindow.h \
    NotesDialog.h

FORMS += \
    MainWindow.ui \
    NotesDialog.ui

RESOURCES += \
    resource.qrc
