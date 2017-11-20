module context;

// dfmt off
private import avatar;
private import settings;
private import util;

private import gdk.Keysyms;
private import gdk.RGBA;
private import gdkpixbuf.Pixbuf;
private import gdkpixbuf.PixbufLoader;
private import gobject.Value;
private import gtk.AboutDialog;
private import gtk.AccelGroup;
private import gtk.Box;
private import gtk.Button;
private import gtk.CellRendererText;
private import gtk.ComboBox;
private import gtk.ComboBoxText;
private import gtk.Container;
private import gtk.Dialog;
private import gtk.Entry;
private import gtk.FileChooserDialog;
private import gtk.Label;
private import gtk.ListStore;
private import gtk.Main;
private import gtk.MainWindow;
private import gtk.Menu;
private import gtk.MenuBar;
private import gtk.MenuItem;
private import gtk.Notebook;
private import gtk.ScrolledWindow;
private import gtk.SeparatorMenuItem;
private import gtk.Statusbar;
private import gtk.TextView;
private import gtk.TreeIter;
private import gtk.TreeView;
private import gtk.TreeViewColumn;
private import std.algorithm.sorting;
private import std.string;
private import std.stdio;
// dfmt on

/// UIContext is simply a container for the application's UI.
class UIContext
{
  private enum versionString = "1.3.0";

  private AvatarLogData m_avatarLogData;
  private Settings m_settings;
  private MainWindow m_mainWindow;
  private Statusbar m_statusBar;
  private ComboBoxText m_avatarsComboBox;
  private ComboBoxText m_datesComboBox;
  private ListStore m_statsListStore;
  private MenuItem m_viewMenuItem;
  private RGBA m_color;

  private void setStatusMessage(string message)
  {
    m_statusBar.removeAll(0);
    m_statusBar.push(0, message);
  }

  private void populateAvatars(string defaultAvatar = "")
  {
    m_avatarsComboBox.removeAll();
    m_datesComboBox.removeAll();
    m_statsListStore.clear();

    // Get the avatar names that have log entries.
    auto avatars = m_avatarLogData.getAvatars();
    if (avatars.length == 0)
    {
      setStatusMessage(t("No avatars found"));
      return;
    }

    // Sort the avatars.
    avatars.sort();

    // Add the avatars to the combo box.
    foreach (avatar; avatars)
    {
      m_avatarsComboBox.appendText(avatar);
    }

    // Attempt to select the default avatar.
    if (defaultAvatar.length > 0)
      m_avatarsComboBox.setActiveText(defaultAvatar);

    // If no avatar is selected then try the very first one in the combo box.
    if (m_avatarsComboBox.getActive() < 0)
      m_avatarsComboBox.setActive(0);
  }

  private void populateDates(string avatar)
  {
    m_datesComboBox.removeAll();
    m_statsListStore.clear();

    // Update the settings.
    m_settings.setAvatar(avatar);

    // Get the stat dates for the avatar.
    auto dates = m_avatarLogData.getStatDates(avatar);
    if (dates.length == 0)
    {
      setStatusMessage(format(t("No stats found for %s"), avatar));
      return;
    }

    // Sort the dates so that the most recent date is first in the combo box.
    // The date strings must be converted to a sortable format during the sort
    // operation.
    dates.sort!((a, b) => dateSortable(a) > dateSortable(b))();

    // Add the dates to the combo box.
    foreach (date; dates)
    {
      m_datesComboBox.appendText(date);
    }

    m_datesComboBox.setActive(0);
  }

  private void populateStats(string avatar, string date, string filter = "")
  {
    m_statsListStore.clear();

    // Get the stats for the avatar and date.
    auto stats = m_avatarLogData.getStats(avatar, date);
    if (stats.length == 0)
    {
      setStatusMessage(format(t("No stats found for %s"), avatar));
      return;
    }

    immutable int[string] order = [
      "VirtueCourage" : -1, "VirtueLove" : -1, "VirtueTruth" : -1,
      "AdventurerLevel" : 0, "ProducerLevel" : 1
    ];

    // Convert the filter string to lower case.
    filter = filter.toLower();

    // Sort the stats according to the order value.
    string[2][][3] bins;
    foreach (stat; stats)
    {
      // Check if the stat is being filtered.
      bool searched;
      if (filter.length > 0)
      {
        // Lower case comparison.
        if (stat[0].toLower().indexOf(filter) >= 0)
          searched = true;
        else
          continue;
      }

      // Check if the stat is in the order associative array.
      if (auto val = stat[0] in order)
      {
        // Don't add items with a negative order value unless it's specifically
        // searched for.
        if (*val >= 0)
          bins[*val] ~= stat;
        else if (searched)
          bins[2] ~= stat;
      }
      else
        bins[2] ~= stat;
    }

    string[3] colors;
    if (m_color.alpha > 0.0)
    {
      colors[0] = "<span foreground='" ~ htmlColor(m_color) ~ "'>%s</span>";
      colors[1] = "<span foreground='" ~ htmlColor(m_color, 0.75) ~ "'>%s</span>";
      colors[2] = "<span foreground='" ~ htmlColor(m_color, 0.5) ~ "'>%s</span>";
    }
    else
    {
      colors[0] = "%s";
      colors[1] = "%s";
      colors[2] = "%s";
    }

    // Add the sorted stats to the tree view.
    foreach (binIndex, bin; bins)
    {
      foreach (stat; bin)
      {
        auto name = new Value(format(colors[binIndex], stat[0]));
        auto value = new Value(format(colors[binIndex], stat[1]));

        TreeIter iter;
        m_statsListStore.insertWithValuesv(iter, -1, [0, 1], [name, value]);
      }
    }

    setStatusMessage(format(t("Showing stats for %s from %s"), avatar, date));
  }

  private void selectLogFolder()
  {
    auto folderDialog = new FileChooserDialog("SotA log folder...",
        m_mainWindow, FileChooserAction.SELECT_FOLDER);
    folderDialog.setFilename(m_settings.getLogFolder());

    switch (folderDialog.run())
    {
    case ResponseType.OK:
      {
        const string folder = folderDialog.getFilename();
        if (m_settings.setLogFolder(folder))
        {
          m_avatarLogData = new AvatarLogData(folder);
          populateAvatars(m_avatarsComboBox.getActiveText());
        }
      }

      break;

    default:
      break;
    }

    folderDialog.close();
  }

  private void modifyNotes(string avatar)
  {
    if (avatar.length == 0)
      return;

    // Create the dialog with OK and Cancel buttons.
    auto notesDialog = new Dialog();
    notesDialog.setDefaultSize(300, 300);
    notesDialog.setTitle(format(t("Notes for %s"), avatar));
    notesDialog.setTransientFor(m_mainWindow);
    notesDialog.addButtons([StockID.OK, StockID.CANCEL], [ResponseType.OK, ResponseType.CANCEL]);

    // Add the text entry field.
    auto textView = new TextView();
    textView.getBuffer().setText(m_settings.getNotes(avatar));
    textView.setVisible(true);

    auto contentArea = notesDialog.getContentArea();
    contentArea.setMarginLeft(3);
    contentArea.setMarginRight(3);
    contentArea.setMarginTop(3);
    contentArea.setMarginBottom(3);
    contentArea.setSpacing(3);
    contentArea.packStart(textView, true, true, 0);

    // Run the dialog and get the result.
    switch (notesDialog.run())
    {
    case ResponseType.OK:
      m_settings.setNotes(avatar, textView.getBuffer().getText());
      break;

    default:
      break;
    }

    notesDialog.close();
  }

  private string getFilter()
  {
    // Create the dialog with OK and Cancel buttons.
    auto filterDialog = new Dialog();
    filterDialog.setDefaultSize(10, 10);
    filterDialog.setTitle(t("Filter"));
    filterDialog.setTransientFor(m_mainWindow);
    filterDialog.addButtons([StockID.OK, StockID.CANCEL], [ResponseType.OK, ResponseType.CANCEL]);

    // Add the text entry field.
    auto entry = new Entry();
    entry.addOnActivate((Entry) { filterDialog.response(ResponseType.OK); });
    entry.setVisible(true);

    auto contentArea = filterDialog.getContentArea();
    contentArea.setMarginLeft(3);
    contentArea.setMarginRight(3);
    contentArea.setMarginTop(3);
    contentArea.setMarginBottom(3);
    contentArea.setSpacing(3);
    contentArea.packStart(entry, false, true, 0);

    // Run the dialog and get the result.
    string filterText;
    switch (filterDialog.run())
    {
    case ResponseType.OK:
      filterText = entry.getText();
      break;

    default:
      break;
    }

    filterDialog.close();
    return filterText;
  }

  private void about()
  {
    enum int logoBorderSize = 2;

    auto icon = m_mainWindow.getIcon();
    immutable int width = icon.getWidth();
    immutable int height = icon.getHeight();

    auto logo = new Pixbuf(icon.getColorspace(), icon.getHasAlpha(),
        icon.getBitsPerSample(), width + logoBorderSize * 2, height + logoBorderSize * 2);
    logo.fill(0x000000FF);
    icon.copyArea(0, 0, width, height, logo, logoBorderSize, logoBorderSize);

    auto aboutDialog = new AboutDialog();
    aboutDialog.setTransientFor(m_mainWindow);
    aboutDialog.setAuthors(["Barugon"]);
    aboutDialog.setComments(m_mainWindow.getTitle());
    aboutDialog.setLicense("The CotA application and it's source code are public domain.");
    aboutDialog.setLogo(logo);
    aboutDialog.setProgramName("CotA");
    aboutDialog.setVersion(versionString);
    aboutDialog.setWebsite("https://github.com/Barugon/CotA");
    aboutDialog.run();
    aboutDialog.close();
  }

  /// Construction initializes the UI.
  this(string appPath)
  {
    m_settings = new Settings(appPath);
    m_avatarLogData = new AvatarLogData(m_settings.getLogFolder());
    m_mainWindow = new MainWindow(t("Companion of the Avatar"));
    m_statusBar = new Statusbar();
    m_statsListStore = new ListStore([GType.STRING, GType.STRING]);
    m_avatarsComboBox = new ComboBoxText(false);
    m_datesComboBox = new ComboBoxText(false);

    // Get the text color.
    auto styleContext = m_mainWindow.getStyleContext();
    if (!styleContext.lookupColor("text_color", m_color))
      styleContext.lookupColor("theme_text_color", m_color);

    // Load the winlow icon.
    auto pixbufLoader = new PixbufLoader();
    if (pixbufLoader.write(cast(char[]) import("icon.png")))
      m_mainWindow.setIcon(pixbufLoader.getPixbuf());
    pixbufLoader.close();

    auto accelGroup = new AccelGroup();
    m_mainWindow.addAccelGroup(accelGroup);

    // Log folder menu item
    auto logFolderMenuItem = new MenuItem((MenuItem) { selectLogFolder(); }, t("_Log Folder..."));

    // Quit menu item
    auto quitMenuItem = new MenuItem((MenuItem) { Main.quit(); }, t("_Quit"), t("Ctrl+Q"));
    quitMenuItem.addAccelerator("activate", accelGroup, GdkKeysyms.GDK_Q,
        GdkModifierType.CONTROL_MASK, GtkAccelFlags.VISIBLE);

    // Setup the file menu.
    auto fileMenu = new Menu();
    fileMenu.append(logFolderMenuItem);
    fileMenu.append(new SeparatorMenuItem());
    fileMenu.append(quitMenuItem);

    auto fileMenuItem = new MenuItem(t("_File"));
    fileMenuItem.setSubmenu(fileMenu);

    // Refresh menu item.
    auto refreshMenuItem = new MenuItem((MenuItem) {
      populateAvatars(m_avatarsComboBox.getActiveText());
    }, t("_Refresh Stats"), t("F5"));
    refreshMenuItem.addAccelerator("activate", accelGroup, GdkKeysyms.GDK_F5,
        cast(GdkModifierType) 0, GtkAccelFlags.VISIBLE);

    // Filter menu item.
    auto filterMenuItem = new MenuItem((MenuItem) {
      auto text = getFilter();
      if (text.length > 0)
        populateStats(m_avatarsComboBox.getActiveText(), m_datesComboBox.getActiveText(), text);
    }, t("_Filter Stats"), t("Ctrl+F"));
    filterMenuItem.addAccelerator("activate", accelGroup, GdkKeysyms.GDK_F,
        GdkModifierType.CONTROL_MASK, GtkAccelFlags.VISIBLE);

    // Setup the view menu.
    auto viewMenu = new Menu();
    viewMenu.append(refreshMenuItem);
    viewMenu.append(filterMenuItem);

    m_viewMenuItem = new MenuItem(t("_View"));
    m_viewMenuItem.setSubmenu(viewMenu);

    // About menu item.
    auto aboutMenuItem = new MenuItem((MenuItem) { about(); }, t("_About"));

    // Setup the help menu.
    auto helpMenu = new Menu();
    helpMenu.append(aboutMenuItem);

    auto helpMenuItem = new MenuItem(t("_Help"));
    helpMenuItem.setSubmenu(helpMenu);

    // Initialize the menu bar.
    auto menuBar = new MenuBar();
    menuBar.append(fileMenuItem);
    menuBar.append(m_viewMenuItem);
    menuBar.append(helpMenuItem);

    auto nameColumn = new TreeViewColumn(t("Name"), new CellRendererText(), "markup", 0);
    nameColumn.setExpand(true);

    auto valueColumn = new TreeViewColumn(t("Value"), new CellRendererText(), "markup", 1);

    auto statsTreeView = new TreeView();
    statsTreeView.appendColumn(nameColumn);
    statsTreeView.appendColumn(valueColumn);
    statsTreeView.setModel(m_statsListStore);

    auto notesButton = new Button(t("Notes"), (Button) {
      modifyNotes(m_avatarsComboBox.getActiveText());
    });

    auto toolBox = new Box(Orientation.HORIZONTAL, 5);
    toolBox.setMarginTop(3);
    toolBox.setMarginBottom(3);
    toolBox.setMarginLeft(5);
    toolBox.setMarginRight(5);
    toolBox.packStart(new Label(t("Avatar:")), false, true, 0);
    toolBox.packStart(m_avatarsComboBox, false, true, 0);
    toolBox.packStart(m_datesComboBox, true, true, 0);
    toolBox.packStart(notesButton, false, true, 0);

    auto statsBox = new Box(Orientation.VERTICAL, 0);
    statsBox.packStart(toolBox, false, true, 0);
    statsBox.packStart(new ScrolledWindow(statsTreeView), true, true, 0);

    auto moongatesBox = new Box(Orientation.VERTICAL, 0);
    moongatesBox.packStart(new Label("Coming soon™"), true, true, 0);

    auto notebook = new Notebook();
    notebook.appendPage(statsBox, t("Stats"));
    notebook.appendPage(moongatesBox, t("Moongates"));
    notebook.addOnSwitchPage((Widget, uint pageNum, Notebook) {
      // Show the view menu only if the stats page is selected.
      if (pageNum == 0)
        m_viewMenuItem.show();
      else
        m_viewMenuItem.hide();
    });

    auto mainBox = new Box(Orientation.VERTICAL, 0);
    mainBox.packStart(menuBar, false, false, 0);
    mainBox.packStart(notebook, true, true, 0);
    mainBox.packStart(m_statusBar, false, true, 0);

    m_mainWindow.setDefaultSize(480, 640);
    m_mainWindow.add(mainBox);

    m_avatarsComboBox.addOnChanged((ComboBox) {
      populateDates(m_avatarsComboBox.getActiveText());
    });

    m_datesComboBox.addOnChanged((ComboBox) {
      populateStats(m_avatarsComboBox.getActiveText(), m_datesComboBox.getActiveText());
    });

    populateAvatars(m_settings.getAvatar());
  }

  /// Show the main window.
  void show()
  {
    m_mainWindow.showAll();
  }
}
