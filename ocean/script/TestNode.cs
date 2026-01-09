using Godot;
using System;
using Godot.Collections;

[Tool]
public partial class TestNode : Node
{
    [Export] public Array<TestResource> Items = new();
}
