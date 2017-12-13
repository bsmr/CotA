module context;

private
{
  import avatar;
  import settings;
  import util;

  import gdk.Keysyms;
  import gdk.RGBA;
  import gdkpixbuf.Pixbuf;
  import gdkpixbuf.PixbufLoader;
  import glib.Timeout;
  import gobject.Value;
  import gtk.AboutDialog;
  import gtk.AccelGroup;
  import gtk.Box;
  import gtk.Button;
  import gtk.CellRendererText;
  import gtk.ComboBox;
  import gtk.ComboBoxText;
  import gtk.Container;
  import gtk.Dialog;
  import gtk.Entry;
  import gtk.FileChooserDialog;
  import gtk.Grid;
  import gtk.Label;
  import gtk.ListStore;
  import gtk.Main;
  import gtk.MainWindow;
  import gtk.Menu;
  import gtk.MenuBar;
  import gtk.MenuItem;
  import gtk.Notebook;
  import gtk.ScrolledWindow;
  import gtk.SeparatorMenuItem;
  import gtk.Statusbar;
  import gtk.TextView;
  import gtk.TreeIter;
  import gtk.TreeView;
  import gtk.TreeViewColumn;
  import std.algorithm.sorting;
  import std.conv;
  import std.string;
  import std.stdio;
  import std.uri;
}

/**
 * UIContext is simply a container for the application's UI.
 */
class UIContext
{
  /**
   * Construction initializes the UI.
   */
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
    m_statOrder = ["VirtueCourage" : -1, "VirtueLove" : -1, "VirtueTruth" : -1,
      "AdventurerLevel" : 0, "ProducerLevel" : 1];

    m_settings = new Settings(appPath);
    m_avatarLogData = new AvatarLogData(m_settings.getLogFolder());

    m_mainWindow = new MainWindow(t("Companion of the Avatar"));
    m_mainWindow.addOnDelete((Event, Widget) {
      // Make sure that the rift timer is stopped when the window is closed.
      if (m_riftTimer !is null)
      {
        m_riftTimer.stop();
        m_riftTimer = null;
      }

      return false;
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

    m_avatarsComboBox = new ComboBoxText(false);
    m_datesComboBox = new ComboBoxText(false);

    m_notesButton = new Button(t("Notes"), (Button) {
      modifyNotes(m_avatarsComboBox.getActiveText());
    });

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

    m_statsListStore = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.DOUBLE]);

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

    m_riftsgrid = new Grid();
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

    m_statusBar = new Statusbar();

    auto mainBox = new Box(Orientation.VERTICAL, 0);
    mainBox.packStart(menuBar, false, false, 0);
    mainBox.packStart(notebook, true, true, 0);
    mainBox.packStart(m_statusBar, false, true, 0);

    m_mainWindow.setResizable(false);
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

  /**
   * Show the main window.
   */
  void show()
  {
    m_mainWindow.showAll();
  }

  private
  {
    enum versionString = "2.0.1";

    enum Page
    {
      stats = 0,
      rifts = 1
    }

    immutable string m_opensText;
    immutable string m_closesText;
    immutable string[8] m_places;
    immutable string[8] m_placeLinks;
    immutable string[8] m_phases;
    immutable int[string] m_statOrder;

    string[int] m_statusMessages;

    AvatarLogData m_avatarLogData;
    Settings m_settings;
    MainWindow m_mainWindow;
    Statusbar m_statusBar;
    ComboBoxText m_avatarsComboBox;
    ComboBoxText m_datesComboBox;
    ListStore m_statsListStore;
    MenuItem m_refreshMenuItem;
    MenuItem m_filterMenuItem;
    Button m_notesButton;
    Grid m_riftsgrid;
    Timeout m_riftTimer;
    RGBA m_textColor;

    void setStatusMessage(int page, string message = [])
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

    void populateAvatars(string defaultAvatar = [])
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
        m_avatarsComboBox.appendText(avatar);

      // Attempt to select the default avatar.
      if (defaultAvatar.length > 0)
        m_avatarsComboBox.setActiveText(defaultAvatar);

      // If no avatar is selected then try the very first one in the combo box.
      if (m_avatarsComboBox.getActive() < 0)
        m_avatarsComboBox.setActive(0);
    }

    void populateDates(string avatar)
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
        m_datesComboBox.appendText(date);

      m_datesComboBox.setActive(0);
    }

    void populateStats(string avatar, string date, string filter = [])
    {
      m_statsListStore.clear();

      // Get the stats for the avatar and date.
      auto stats = m_avatarLogData.getStats(avatar, date);
      if (stats.length == 0)
      {
        setStatusMessage(Page.stats, format(t("No stats found for %s"), avatar));
        return;
      }

      // Sort the stats according to the order value.
      AvatarLogData.Stat[][3] bins;
      foreach (stat; stats)
      {
        // Check if the stat is being filtered.
        bool searched;
        if (filter.length > 0)
        {
          if (stat.name.indexOf(filter, CaseSensitive.no) < 0)
            continue;

          searched = true;
        }

        // Check if the stat is in the order associative array.
        if (auto val = stat.name in m_statOrder)
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
          auto name = new Value(markup[binIndex].replace("%s", stat.name));
          auto value = new Value(markup[binIndex].replace("%s", stat.value));
          auto nameSort = new Value(stat.name);
          auto valueSort = new Value(to!(double)(stat.value));

          TreeIter iter;
          m_statsListStore.insertWithValuesv(iter, -1, [0, 1, 2, 3], [name,
              value, nameSort, valueSort]);
        }
      }

      m_filterMenuItem.setSensitive(true);
      setStatusMessage(Page.stats, format(t("Showing stats for %s from %s"), avatar, date));
    }

    void updateLunarRifts()
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
        riftMarkup = "<span foreground='" ~ htmlColor(m_textColor,
            0.5) ~ "'>" ~ m_opensText ~ "</span>";
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
            placeLabel.setText(
                "<a href=\"" ~ m_placeLinks[riftNum] ~ "\">" ~ m_places[riftNum] ~ "</a>");
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

    void selectLogFolder()
    {
      auto folderDialog = new FileChooserDialog(t("Select SotA Log Folder"),
          m_mainWindow, FileChooserAction.SELECT_FOLDER);
      folderDialog.setFilename(m_settings.getLogFolder());

      if (folderDialog.run() == ResponseType.OK)
      {
        const string folder = folderDialog.getFilename();
        if (m_settings.setLogFolder(folder))
        {
          m_avatarLogData = new AvatarLogData(folder);
          populateAvatars(m_avatarsComboBox.getActiveText());
        }
      }

      folderDialog.close();
    }

    void modifyNotes(string avatar)
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
      if (notesDialog.run() == ResponseType.OK)
        m_settings.setNotes(avatar, textView.getBuffer().getText());

      notesDialog.close();
    }

    string getFilter()
    {
      // Create the dialog with OK and Cancel buttons.
      auto filterDialog = new Dialog();
      filterDialog.setDefaultSize(10, 10);
      filterDialog.setTitle(t("Filter"));
      filterDialog.setTransientFor(m_mainWindow);
      filterDialog.addButtons([StockID.OK, StockID.CANCEL], [ResponseType.OK,
          ResponseType.CANCEL]);

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
      if (filterDialog.run() == ResponseType.OK)
        filterText = entry.getText();

      filterDialog.close();
      return filterText;
    }

    void about()
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
  }
}
