private
{
  import context;
  import gtk.Main;
}

void main(string[] args)
{
  Main.init(args);

  auto context = new UIContext(args[0]);
  context.show();

  Main.run();
}
