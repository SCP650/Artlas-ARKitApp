# ARSigns-ARKitApp
What is this building? This app uses ARkit's GeoTracking feature to project building names on top of buildings in AR!

# Under the hood

Artlas uses Apple ARKit's Geotracking feature. It uses your GPS coordinates and the image stream captured from your camera to understand where you are in the real world. Then it searches for nearby places of interest using MapKit and finds the nearest one in the direction you are pointing towards when you hit the button. Then it will generate a 3D text object using RealityKit and place it at the location of the building.

We value privacy so we do not store any user information. Everything is done locally using Apple's native APIs.
