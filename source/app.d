// dfmt off
private import context;
private import gtk.Main;
// dfmt on

void main(string[] args)
{
  Main.init(args);

  auto context = new UIContext(args[0]);
  context.show();

  Main.run();
}
