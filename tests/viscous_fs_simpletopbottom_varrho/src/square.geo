Point(1) = {0, 0, 0};
Extrude {1, 0, 0} {
  Point{1}; Layers{20};
}
Extrude {0, 1, 0} {
  Line{1}; Layers{20};
}
// Bottom
Physical Line(6) = {1};
Physical Line(7) = {4};
// Top
Physical Line(8) = {2};
Physical Line(9) = {3};
Physical Surface(10) = {5};
