enum BackgroundType {
  color,
  image;

  static BackgroundType fromString(String value) {
    switch (value) {
      case 'color':
        return BackgroundType.color;
      case 'image':
        return BackgroundType.image;
      default:
        return BackgroundType.color;
    }
  }
}