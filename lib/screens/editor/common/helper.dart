import 'package:com.codestagevn.gridpicture/screens/editor/common/constants.dart';
import 'package:com.codestagevn.gridpicture/screens/editor/widgets/loading.dart';
import 'package:flutter/material.dart';

List<Rect> getCropAreasOfImage(Rect area, CropNumber cropNumber) {
  List<Rect> areas = [];

  switch(cropNumber) {
    case CropNumber.TwoH:
      areas.add(Rect.fromLTWH(area.left, area.top, area.width, area.height / 2));
      areas.add(Rect.fromLTWH(area.left, area.height / 2, area.width, area.height / 2));
    break;
    case CropNumber.TwoV:
      areas.add(Rect.fromLTWH(area.left, area.top, area.width / 2, area.height));
      areas.add(Rect.fromLTWH(area.left + area.width / 2, area.top, area.width / 2, area.height));
      break;
    case CropNumber.Three:
      areas.add(Rect.fromLTRB(area.left, area.top, area.right, area.bottom * 2/3));
      areas.add(Rect.fromLTRB(area.left, area.bottom * 2/3, area.right / 2, area.bottom));
      areas.add(Rect.fromLTRB(area.right / 2, area.bottom * 2/3, area.right, area.bottom));
      break;
    case CropNumber.Four:
      areas.add(Rect.fromLTRB(area.left, area.top, area.right, area.bottom * 2/3));
      areas.add(Rect.fromLTRB(area.left, area.bottom * 2/3, area.right * 1/3, area.bottom));
      areas.add(Rect.fromLTRB(area.right * 1/3, area.bottom * 2/3, area.right * 2/3, area.bottom));
      areas.add(Rect.fromLTRB(area.right * 2/3, area.bottom * 2/3, area.right, area.bottom));
      break;
    case CropNumber.Nine:
      for(int i = 1; i <= 3; i++) {
        for(int j = 1; j <= 3; j++) {
          areas.add(Rect.fromLTRB(
              area.right - (area.right * (3 - j) / 3) - area.right * 1/3,
              area.bottom - (area.bottom * (3 - i) / 3) - area.bottom * 1/3,
              area.right - (area.right * (3 - j) / 3), //
              area.bottom - (area.bottom * (3 - i) / 3)
          ));
        }
      }
      break;
  }

  print('Crop areas: $areas');
  return areas;
}

void showLoading(context) {
  showDialog(
    barrierDismissible: false,
    barrierColor: Colors.black54,
    context: context,
    builder: (context) {
      return Loading();
    }
  );
}