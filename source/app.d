private
{
  import context;
  import gtk.Main;
}

void main(string[] args)
{
  Main.init(args);

  with (new UIContext(args[0]))
    Main.run();
}
