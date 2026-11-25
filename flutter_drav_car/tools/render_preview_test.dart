// Run with flutter test tools/render_preview_test.dart to export the Canvas art sheet.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_driver/game/game_model.dart';
import 'package:little_driver/game/road_painter.dart';
void main() {
  testWidgets('Export vehicle art preview', (tester) async {
    await tester.runAsync(() async {
      final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);
      for(final form in VehicleForm.values) {
        canvas.save();canvas.translate(form.index*320.0,0);
        final g=GameModel()..state=PlayState.driving..distance=2..rideTime=3;
        if(form!=VehicleForm.car)g.transform(form);
        g.items.addAll([RoadItem(-.72,.46,ItemKind.cone),RoadItem(.72,.54,ItemKind.coin),RoadItem(.72,.65,ItemKind.coin)]);
        RoadPainter(game:g,world:WorldTheme.all[0]).paint(canvas,const Size(320,600));
        canvas.restore();
      }
      final picture=recorder.endRecording();
      final image=await picture.toImage(1600,600);
      final data=await image.toByteData(format:ui.ImageByteFormat.png);
      await File('docs/qa/v11-forms.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();picture.dispose();
    });
  });
}
