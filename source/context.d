module context;

// dfmt off
private import avatar;
private import settings;
private import util;

private import gdk.Keysyms;
private import gdk.RGBA;
private import gdkpixbuf.Pixbuf;
private import gdkpixbuf.PixbufLoader;
private import glib.Timeout;
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
private import gtk.Grid;
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
private import std.conv;
private import std.string;
private import std.stdio;
private import std.uri;
// dfmt on

/// UIContext is simply a container for the application's UI.
class UIContext
{
  private enum versionString = "2.0.1";

  private enum Page
  {
    stats = 0,
    rifts = 1
  }

  private immutable string m_opensText;
  private immutable string m_closesText;
  private immutable string[8] m_places;
  private immutable string[8] m_placeLinks;
  private immutable string[8] m_phases;

  private AvatarLogData m_avatarLogData;
  private Settings m_settings;
  private MainWindow m_mainWindow;
  private Statusbar m_statusBar;
  private ComboBoxText m_avatarsComboBox;
  private ComboBoxText m_datesComboBox;
  private ListStore m_statsListStore;
  private RGBA m_textColor;

  private MenuItem m_refreshMenuItem;
  private MenuItem m_filterMenuItem;
  private Button m_notesButton;

  private Grid m_riftsgrid;
  private Timeout m_riftTimer;

  private string[int] m_statusMessages;

  private void setStatusMessage(int page, string message = [])
  {
    if (message is null)
    {
      if (auto val = page in m_statusMessages)
        message = *val;
    }
    else
      m_statusMessages[page] = message;

    m_statusBar.removeAll(0);
    if (message !is null)
      m_statusBar.push(0, message);
  }

  private void populateAvatars(string defaultAvatar = [])
  {
    m_avatarsComboBox.removeAll();
    m_datesComboBox.removeAll();
    m_statsListStore.clear();
    m_filterMenuItem.setSensitive(false);
    m_notesButton.setSensitive(false);

    // Get the avatar names that have log entries.
    auto avatars = m_avatarLogData.getAvatars();
    if (avatars.length == 0)
    {
      setStatusMessage(Page.stats, t("No avatars found"));
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
    m_filterMenuItem.setSensitive(false);
    m_notesButton.setSensitive(avatar.length > 0);

    // Update the settings.
    m_settings.setAvatar(avatar);

    // Get the stat dates for the avatar.
    auto dates = m_avatarLogData.getStatDates(avatar);
    if (dates.length == 0)
    {
      setStatusMessage(Page.stats, format(t("No stats found for %s"), avatar));
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

  private void populateStats(string avatar, string date, string filter = [])
  {
    m_statsListStore.clear();

    // Get the stats for the avatar and date.
    auto stats = m_avatarLogData.getStats(avatar, date);
    if (stats.length == 0)
    {
      setStatusMessage(Page.stats, format(t("No stats found for %s"), avatar));
      return;
    }

    immutable int[string] order = [
      "VirtueCourage" : -1, "VirtueLove" : -1, "VirtueTruth" : -1,
      "AdventurerLevel" : 0, "ProducerLevel" : 1
    ];

    // Sort the stats according to the order value.
    string[2][][3] bins;
    foreach (stat; stats)
    {
      // Check if the stat is being filtered.
      bool searched;
      if (filter.length > 0)
      {
        if (stat[0].indexOf(filter, CaseSensitive.no) >= 0)
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

    string[3] markup;
    if (m_textColor.alpha > 0.0)
    {
      markup[0] = "<span foreground='" ~ htmlColor(m_textColor) ~ "'>%s</span>";
      markup[1] = "<span foreground='" ~ htmlColor(m_textColor, 0.75) ~ "'>%s</span>";
      markup[2] = "<span foreground='" ~ htmlColor(m_textColor, 0.5) ~ "'>%s</span>";
    }
    else
    {
      markup[0] = "%s";
      markup[1] = "%s";
      markup[2] = "%s";
    }

    // Add the sorted stats to the tree view.
    foreach (binIndex, bin; bins)
    {
      foreach (stat; bin)
      {
        auto name = new Value(markup[binIndex].replace("%s", stat[0]));
        auto value = new Value(markup[binIndex].replace("%s", stat[1]));
        auto nameSort = new Value(stat[0]);
        auto valueSort = new Value(to!(double)(stat[1]));

        TreeIter iter;
        m_statsListStore.insertWithValuesv(iter, -1, [0, 1, 2, 3], [name,
            value, nameSort, valueSort]);
      }
    }

    m_filterMenuItem.setSensitive(true);
    setStatusMessage(Page.stats, format(t("Showing stats for %s from %s"), avatar, date));
  }

  private void updateLunarRifts()
  {
    // Get the lunar phase.
    immutable auto phase = getLunarPhase();
    int riftNum = cast(int) phase;

    // Get the time remaining for the active lunar rift.
    immutable double remain = 8.75 * (1.0 - (phase - riftNum));
    int minutes = cast(int) remain;
    int seconds = cast(int)(60.0 * (remain - minutes) + 0.5);
    if (seconds > 59)
    {
      ++minutes;
      seconds -= 60;
    }

    string phaseMarkup;
    string riftMarkup;
    if (m_textColor.alpha() > 0.0)
    {
      phaseMarkup = "<span foreground='" ~ htmlColor(m_textColor, 0.5) ~ "'>%s</span>";
      riftMarkup = "<span foreground='" ~ htmlColor(m_textColor, 0.5) ~ "'>"
        ~ m_opensText ~ "</span>";
    }
    else
    {
      phaseMarkup = "%s";
      riftMarkup = m_opensText;
    }

    for (int num; num < 8; ++num)
    {
      if (num == 0)
      {
        // The first item is the active lunar rift.
        if (auto placeLabel = cast(Label) m_riftsgrid.getChildAt(0, riftNum))
        {
          placeLabel.setText(
              "<a href=\"" ~ m_placeLinks[riftNum] ~ "\"><b>" ~ m_places[riftNum] ~ "</b></a>");
          placeLabel.setUseMarkup(true);
        }

        if (auto phaseLabel = cast(Label) m_riftsgrid.getChildAt(1, riftNum))
          phaseLabel.setText(m_phases[riftNum]);

        if (auto riftLabel = cast(Label) m_riftsgrid.getChildAt(2, riftNum))
          riftLabel.setText(format(m_closesText, minutes, seconds));
      }
      else
      {
        // Draw the inactive lunar rifts in a less pronounced way.
        if (auto placeLabel = cast(Label) m_riftsgrid.getChildAt(0, riftNum))
        {
          placeLabel.setText("<a href=\"" ~ m_placeLinks[riftNum] ~ "\">"
              ~ m_places[riftNum] ~ "</a>");
          placeLabel.setUseMarkup(true);
        }

        if (auto phaseLabel = cast(Label) m_riftsgrid.getChildAt(1, riftNum))
        {
          phaseLabel.setText(phaseMarkup.replace("%s", m_phases[riftNum]));
          phaseLabel.setUseMarkup(true);
        }

        if (auto riftLabel = cast(Label) m_riftsgrid.getChildAt(2, riftNum))
        {
          riftLabel.setText(format(riftMarkup, minutes, seconds));
          riftLabel.setUseMarkup(true);
        }

        // Add time for the next lunar rift.
        minutes += 8;
        seconds += 45;
        if (seconds > 59)
        {
          ++minutes;
          seconds -= 60;
        }
      }

      if (++riftNum > 7)
        riftNum = 0;
    }
  }

  private void selectLogFolder()
  {
    auto folderDialog = new FileChooserDialog(t("Select SotA log folder..."),
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
    textView.setVisible(true);

    // Get previously stored notes.
    auto text = m_settings.getNotes(avatar);
    if (text.length > 0)
      textView.getBuffer().setText(text);

    auto contentArea = notesDialog.getContentArea();
    contentArea.setMargins(3, 3, 3, 3);
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
    contentArea.setMargins(3, 3, 3, 3);
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

    // Create the logo with a 2px black border.
    auto logo = new Pixbuf(icon.getColorspace(), icon.getHasAlpha(),
        icon.getBitsPerSample(), width + logoBorderSize * 2, height + logoBorderSize * 2);
    logo.fill(0x000000FF);
    icon.copyArea(0, 0, width, height, logo, logoBorderSize, logoBorderSize);

    auto aboutDialog = new AboutDialog();
    aboutDialog.setTransientFor(m_mainWindow);
    aboutDialog.setAuthors(["Barugon"]);
    aboutDialog.setComments(m_mainWindow.getTitle());
    aboutDialog.setLicense(t("The CotA application and it's source code are public domain."));
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
    m_opensText = t("Opens in %02dm %02ds");
    m_closesText = t("Closes in %02dm %02ds");
    m_places = [t("Blood River"), t("Solace Bridge"), t("Highvale"),
      t("Brookside"), t("Owl's Head"), t("Westend"), t("Brittany Graveyard"), t("Etceter")];
    m_placeLinks = ["https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=310&amp;openPopup=true&amp;z=4",
      "https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=2757&amp;openPopup=true&amp;z=4",
      "https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=999&amp;openPopup=true&amp;z=4",
      "https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=434&amp;openPopup=true&amp;z=4",
      "https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=444&amp;openPopup=true&amp;z=4",
      "https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=587&amp;openPopup=true&amp;z=4",
      "https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=1054&amp;openPopup=true&amp;z=4",
      "https://www.shroudoftheavatar.com/map/?map_id=1&amp;poi_id=632&amp;openPopup=true&amp;z=4"];
    m_phases = [t("New Moon"), t("Waxing Crescent"), t("First Quarter"),
      t("Waxing Gibbous"), t("Full Moon"), t("Waning Gibbous"),
      t("Third Quarter"), t("Waning Crescent")];

    m_settings = new Settings(appPath);
    m_avatarLogData = new AvatarLogData(m_settings.getLogFolder());
    m_mainWindow = new MainWindow(t("Companion of the Avatar"));
    m_statusBar = new Statusbar();
    m_statsListStore = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.DOUBLE]);
    m_avatarsComboBox = new ComboBoxText(false);
    m_datesComboBox = new ComboBoxText(false);
    m_notesButton = new Button(t("Notes"));
    m_riftsgrid = new Grid();

    m_notesButton.addOnClicked((Button) {
      modifyNotes(m_avatarsComboBox.getActiveText());
    });

    // Get the text color.
    auto styleContext = m_mainWindow.getStyleContext();
    if (!styleContext.lookupColor("text_color", m_textColor))
      styleContext.lookupColor("theme_text_color", m_textColor);

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
    m_refreshMenuItem = new MenuItem((MenuItem) {
      populateAvatars(m_avatarsComboBox.getActiveText());
    }, t("_Refresh Stats"), t("F5"));
    m_refreshMenuItem.addAccelerator("activate", accelGroup, GdkKeysyms.GDK_F5,
        cast(GdkModifierType) 0, GtkAccelFlags.VISIBLE);

    // Filter menu item.
    m_filterMenuItem = new MenuItem((MenuItem) {
      auto text = getFilter();
      if (text.length > 0)
        populateStats(m_avatarsComboBox.getActiveText(), m_datesComboBox.getActiveText(), text);
    }, t("_Filter Stats"), t("Ctrl+F"));
    m_filterMenuItem.addAccelerator("activate", accelGroup, GdkKeysyms.GDK_F,
        GdkModifierType.CONTROL_MASK, GtkAccelFlags.VISIBLE);

    // Setup the view menu.
    auto viewMenu = new Menu();
    viewMenu.append(m_refreshMenuItem);
    viewMenu.append(m_filterMenuItem);

    auto viewMenuItem = new MenuItem(t("_View"));
    viewMenuItem.setSubmenu(viewMenu);

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
    menuBar.append(viewMenuItem);
    menuBar.append(helpMenuItem);

    auto nameColumn = new TreeViewColumn(t("Name"), new CellRendererText(), "markup", 0);
    nameColumn.setSortColumnId(2);
    nameColumn.setExpand(true);

    auto valueColumn = new TreeViewColumn(t("Value"), new CellRendererText(), "markup", 1);
    valueColumn.setSortColumnId(3);

    auto statsTreeView = new TreeView();
    statsTreeView.appendColumn(nameColumn);
    statsTreeView.appendColumn(valueColumn);
    statsTreeView.setModel(m_statsListStore);

    auto toolBox = new Box(Orientation.HORIZONTAL, 5);
    toolBox.setMargins(5, 3, 5, 3);
    toolBox.packStart(new Label(t("Avatar:")), false, true, 0);
    toolBox.packStart(m_avatarsComboBox, false, true, 0);
    toolBox.packStart(m_datesComboBox, true, true, 0);
    toolBox.packStart(m_notesButton, false, true, 0);

    auto statsBox = new Box(Orientation.VERTICAL, 0);
    statsBox.packStart(toolBox, false, true, 0);
    statsBox.packStart(new ScrolledWindow(statsTreeView), true, true, 0);

    m_riftsgrid.setMargins(5, 5, 5, 5);

    // Add the labels to the lunar rifts grid.
    for (int index; index < 8; ++index)
    {
      auto placeLabel = new Label("");
      placeLabel.setHalign(Align.START);
      placeLabel.setMargins(3, 3, 3, 3);
      m_riftsgrid.attach(placeLabel, 0, index, 1, 1);

      auto phaseLabel = new Label("");
      phaseLabel.setHexpand(true);
      phaseLabel.setMargins(3, 3, 3, 3);
      m_riftsgrid.attach(phaseLabel, 1, index, 1, 1);

      auto riftLabel = new Label("");
      riftLabel.setHalign(Align.END);
      riftLabel.setMargins(3, 3, 3, 3);
      m_riftsgrid.attach(riftLabel, 2, index, 1, 1);
    }

    auto chronoLabel = new Label(
        t("The accuracy of this lunar rift chronometer\n" ~ "depends entirely on your system clock.\n\n"
        ~ "For best results, please set your system\n" ~ "clock to synchronize with internet time."));
    chronoLabel.setJustify(Justification.CENTER);

    auto riftsBox = new Box(Orientation.VERTICAL, 10);
    riftsBox.packStart(m_riftsgrid, false, true, 0);
    riftsBox.packStart(chronoLabel, true, true, 0);

    auto notebook = new Notebook();
    notebook.insertPage(statsBox, new Label(t("Stats")), Page.stats);
    notebook.insertPage(riftsBox, new Label(t("Lunar Rifts")), Page.rifts);
    notebook.addOnSwitchPage((Widget, uint pageNum, Notebook) {
      if (pageNum == Page.stats)
      {
        if (m_riftTimer !is null)
        {
          m_riftTimer.stop();
          m_riftTimer = null;
        }

        // Restore stat related view menu items.
        m_refreshMenuItem.setSensitive(true);

        TreeIter iter;
        if (m_statsListStore.getIterFirst(iter))
          m_filterMenuItem.setSensitive(true);
      }
      else
      {
        if (pageNum == Page.rifts)
          m_riftTimer = new Timeout(1000, () { updateLunarRifts(); return true; }, true);

        // Disable stat related view menu items if the stats page is not active.
        m_refreshMenuItem.setSensitive(false);
        m_filterMenuItem.setSensitive(false);
      }

      setStatusMessage(pageNum);
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
