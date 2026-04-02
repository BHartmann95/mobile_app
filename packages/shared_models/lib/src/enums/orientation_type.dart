enum OrientationType {
  portrait,
  landscape;

  static OrientationType fromString(String value) {
    switch (value) {
      case 'portrait':
        return OrientationType.portrait;
      case 'landscape':
        return OrientationType.landscape;
      default:
        return OrientationType.landscape;
    }
  }
}