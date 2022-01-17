import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

void main() async{
  runApp(App());
}

const String pcmodel = "pcmodel";

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

enum AppState {
  free,
  picked,
  cropped,
}

class _MyAppState extends State<MyApp> {
  late AppState gallery_state = AppState.free;
  late AppState camera_state = AppState.free;
  File? _image;
  List? _recognitions;
  String _model = pcmodel;
  double? _imageHeight;
  double? _imageWidth;
  bool _busy = false;
  bool _isButtonDisabled = true;

  String _label = "";
  String _index = "";
  String _confidence = "";

  Future<Null> _cropImage() async {
    File? croppedFile = await ImageCropper.cropImage(
        sourcePath: _image!.path,
        aspectRatioPresets: Platform.isAndroid
            ? [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9
        ]
            : [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio5x3,
          CropAspectRatioPreset.ratio5x4,
          CropAspectRatioPreset.ratio7x5,
          CropAspectRatioPreset.ratio16x9
        ],
        androidUiSettings: AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        iosUiSettings: IOSUiSettings(
          title: 'Cropper',
        ));
    if (croppedFile != null) {
      _image = croppedFile;
      setState(() {
        if(gallery_state == AppState.picked){
          gallery_state = AppState.cropped;
          camera_state = AppState.free;
        }
        else if(camera_state == AppState.picked){
          camera_state = AppState.cropped;
          gallery_state = AppState.free;
        }
      });
    }
  }
  void _clearImage() {
    _image = null;
    setState(() {
      gallery_state = AppState.free;
      camera_state = AppState.free;
      _label = "";
      _index = "";
      _confidence = "";
    });
  }
  Future predictGalleryImage() async {
    XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 200, maxHeight: 200);
    File imageFile = File(image!.path);
    if (imageFile == null) return;
    setState(() {
      _busy = true;
      _image = imageFile;
      _isButtonDisabled = false;
      gallery_state = AppState.picked;
      camera_state = AppState.free;
    });
    //predictImage(image);
    //predictImage(imageFile);
  }

  Future predictCameraImage() async {
    XFile? image = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 200, maxHeight: 200);
    File imageFile = File(image!.path);
    if (imageFile == null) return;
    setState(() {
      _busy = true;
      _image = imageFile;
      _isButtonDisabled = false;
      camera_state = AppState.picked;
      gallery_state = AppState.free;
    });
    //predictImage(image);
    //predictImage(imageFile);
  }

  Future predictImage(File image) async {
    if (image == null) {
      return;
    }

    await MY_MODEL(image);

    FileImage(image)
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      setState(() {
        _imageHeight = info.image.height.toDouble();
        _imageWidth = info.image.width.toDouble();
      });
    }));

    setState(() {
      _image = image;
      _busy = false;
    });
  }

  @override
  void initState() {
    super.initState();
    camera_state = AppState.free;
    gallery_state = AppState.free;
    _isButtonDisabled = true;
    _label = "";
    _index = "";
    _confidence = "";
    _busy = true;

    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  Future loadModel() async {
    Tflite.close();
    try {
      await Tflite.loadModel(
          model: "assets/my_model.tflite",
          labels: "assets/my_model.txt"
      );
    }
    catch(e)
    {
      print(e);
    }
  }

  Future MY_MODEL(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    List? recognitions = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 1,
    );
    setState(() {
      _recognitions = recognitions;
      _label = recognitions![0]['label'].toString();
      _index = recognitions[0]['index'].toString();
      _confidence = recognitions[0]['confidence'].toString();

    });
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
  }

  onSelect(model) async {
    setState(() {
      _busy = true;
      _model = model;
      _recognitions = null;
      _label = "";
      _index = "";
    });
    await loadModel();

    if (_image != null) {
      predictImage(_image!);
    } else {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    if(_image == null) _isButtonDisabled=true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traffic Recognition using ML'),
        centerTitle: true,
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: onSelect,
            itemBuilder: (context) {
              List<PopupMenuEntry<String>> menuEntries = [
                const PopupMenuItem<String>(
                  child: Text(pcmodel),
                  value: pcmodel,
                ),
              ];
              return menuEntries;
            },
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        children: [
          SpeedDialChild(
            label: "Remove Image",
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            child: const Icon(Icons.close_rounded),
            onTap: _clearImage,
          ),
          SpeedDialChild(
            label: "Crop",
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            child: const Icon(Icons.crop),
            onTap: _cropImage,
          ),
          SpeedDialChild(
            label: "Camera",
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.camera_enhance_rounded),
            onTap: predictCameraImage,
          ),
          SpeedDialChild(
            label: "Gallery",
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.image_search_rounded),
            onTap: predictGalleryImage,
          ),
        ],
      ),
      body:
      Stack(
        //alignment: AlignmentDirectional.topCenter,
        children: //stackChildren,
        <Widget>[
          Positioned(
            bottom: 55.0,
            left: 100,
            child:
            Transform.scale(
              scale: 2.5,
              child:
              ElevatedButton(
                onPressed: _isButtonDisabled ? null : ()=> predictImage(_image!),
                child: const Text("Classify"),
              ),
            ),
          ),
          Positioned(
            top: 5,
            left: 30,
            child:Container(
            //alignment: Alignment.topCenter,
            margin: const EdgeInsets.all(40.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.lightBlue),
              borderRadius: BorderRadius.circular(16),
            ),
            width: 200,
            height: 200,
            child: _image == null ? Image.asset("assets/no_selection.png") : Image.file(_image!),
            ),
          ),
          Positioned(
            top: 300,
            left: 50,
            child:
            Text(_label != null ? 'Label = $_label' : "Empty"),
          ),
          Positioned(
            top: 320,
            left: 50,
            child:
            Text(_index != null ? 'index = $_index' : "Empty",),
          ),
          Positioned(
            top: 340,
            left: 50,
            child:
            Text(_confidence != null ? 'confidence = $_confidence' : "Empty"),
          ),
        ],
      ),
    );
  }
}