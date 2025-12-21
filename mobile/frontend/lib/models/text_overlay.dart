import 'package:flutter/material.dart';

/// Text Overlay Model for Video Editing
/// Represents a text overlay that can be added to video
class TextOverlay {
  final String id;
  String text;
  Duration startTime;
  Duration endTime;
  double x; // Position X (0.0 to 1.0)
  double y; // Position Y (0.0 to 1.0)
  String fontFamily;
  double fontSize;
  int color; // Color as ARGB int
  TextAlign textAlign;
  String? backgroundColor; // Optional background color
  
  TextOverlay({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.x = 0.5,
    this.y = 0.5,
    this.fontFamily = 'Roboto',
    this.fontSize = 24.0,
    this.color = 0xFFFFFFFF, // White by default
    this.textAlign = TextAlign.center,
    this.backgroundColor,
  });
  
  TextOverlay copyWith({
    String? id,
    String? text,
    Duration? startTime,
    Duration? endTime,
    double? x,
    double? y,
    String? fontFamily,
    double? fontSize,
    int? color,
    TextAlign? textAlign,
    String? backgroundColor,
  }) {
    return TextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      x: x ?? this.x,
      y: y ?? this.y,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      textAlign: textAlign ?? this.textAlign,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'startTime': startTime.inSeconds,
      'endTime': endTime.inSeconds,
      'x': x,
      'y': y,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'color': color,
      'textAlign': textAlign.index,
      'backgroundColor': backgroundColor,
    };
  }
  
  factory TextOverlay.fromJson(Map<String, dynamic> json) {
    return TextOverlay(
      id: json['id'],
      text: json['text'],
      startTime: Duration(seconds: json['startTime']),
      endTime: Duration(seconds: json['endTime']),
      x: json['x']?.toDouble() ?? 0.5,
      y: json['y']?.toDouble() ?? 0.5,
      fontFamily: json['fontFamily'] ?? 'Roboto',
      fontSize: json['fontSize']?.toDouble() ?? 24.0,
      color: json['color'] ?? 0xFFFFFFFF,
      textAlign: TextAlign.values[json['textAlign'] ?? 0],
      backgroundColor: json['backgroundColor'],
    );
  }
}

