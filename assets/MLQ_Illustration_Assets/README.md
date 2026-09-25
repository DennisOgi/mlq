# MLQ illustration assets

11 separate WebP images, each 1600 x 1200, each below 250,000 bytes. Generated with the built-in image generator, then resized and encoded as WebP. The corrected Leadership, Emotions and Health versions are included. Optional illustrations are not included.

Copy assets/images/ui/covers/ into your Flutter project. Add this directory under the existing flutter section in pubspec.yaml (merge it; do not create a second flutter section):

```yaml
flutter:
  assets:
    - assets/images/ui/covers/
```

Use a cover:

```dart
AspectRatio(
  aspectRatio: 4 / 3,
  child: Image.asset(
    'assets/images/ui/covers/leadership.webp',
    fit: BoxFit.cover,
  ),
)
```

Use the eight topic names as explicit cover_key values. The three goal images have the goal_ prefix. Prefer the original 4:3 framing; review square and 16:9 crops individually because peripheral scenery and some figures will be cropped. These are opaque cover illustrations, not transparent cutouts. Add titles using Flutter widgets.

The illustrations have been visually reviewed, but have not been tested inside your app. Retain your existing Questor images for headers and empty states.
