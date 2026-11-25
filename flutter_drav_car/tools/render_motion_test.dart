// Export native Canvas motion previews with flutter test tools/render_motion_test.dart.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_driver/game/game_model.dart';
import 'package:little_driver/game/road_painter.dart';
void main() {
  testWidgets('Export vehicle motion and impact preview', (tester) async {
    await tester.runAsync(() async {
      // Widget tests use a square test font. Load a real font for the exported score labels.
      final bytes=await File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytes();
      await (FontLoader('Preview')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      for(final value in [1,2]) {
        RoadPainter.rewardLabels[value]=TextPainter(text:TextSpan(text:'+$value',style:const TextStyle(
          fontFamily:'Preview',fontSize:22,fontWeight:FontWeight.w900,color:Color(0xfffff2b0),
          shadows:[Shadow(color:Color(0x885a733d),blurRadius:3,offset:Offset(0,2))])),textDirection:TextDirection.ltr)..layout();
      }
      final dir=Directory('/tmp/drive_v12_frames');await dir.create(recursive:true);
      final games=VehicleForm.values.map((form) {
        final g=GameModel()..state=PlayState.driving..distance=2..spawnIn=10000;
        if(form!=VehicleForm.car)g.transform(form);
        g.items.addAll([RoadItem(-.72,.36,ItemKind.cone),RoadItem(.72,.48,ItemKind.coin),RoadItem(0,.45,ItemKind.coin)]);
        return g;
      }).toList();
      for(var frame=0;frame<24;frame++) {
        final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);
        for(var i=0;i<games.length;i++) {
          final g=games[i];
          if(frame==12)g.items.add(RoadItem(0,.74,ItemKind.cone));
          if(frame>0)g.update(.1);
          canvas.save();canvas.translate(i*320.0,0);
          RoadPainter(game:g,world:WorldTheme.all[0]).paint(canvas,const Size(320,600));canvas.restore();
        }
        final picture=recorder.endRecording();final image=await picture.toImage(1600,600);
        final data=await image.toByteData(format:ui.ImageByteFormat.png);
        await File('${dir.path}/frame-${frame.toString().padLeft(2,'0')}.png').writeAsBytes(data!.buffer.asUint8List());
        if(frame==13)await File('docs/qa/v12-feedback.png').writeAsBytes(data.buffer.asUint8List());
        image.dispose();picture.dispose();
      }
    });
  });
}
