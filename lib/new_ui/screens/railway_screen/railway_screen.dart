// ignore_for_file: lines_longer_than_80_chars
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:tsec_app/models/concession_details_model/concession_details_model.dart';
import 'package:tsec_app/models/concession_request_model/concession_request_model.dart';
// import 'package:tsec_app/models/concession_request_model/concession_request_model.dart';
import 'package:tsec_app/models/student_model/student_model.dart';
import 'package:tsec_app/new_ui/screens/railway_screen/railwayform.dart';
import 'package:tsec_app/new_ui/screens/railway_screen/widgets/concession_status_modal.dart';
import 'package:tsec_app/new_ui/screens/railway_screen/widgets/railway_dropdown_search.dart';
import 'package:tsec_app/new_ui/screens/railway_screen/widgets/railway_dropdown_field.dart';
import 'package:tsec_app/new_ui/screens/railway_screen/widgets/stepperwidget.dart';
import 'package:tsec_app/provider/auth_provider.dart';
import 'package:tsec_app/provider/concession_provider.dart';
import 'package:tsec_app/provider/concession_request_provider.dart';
import 'package:tsec_app/provider/railway_concession_provider.dart';
import 'package:tsec_app/new_ui/screens/railway_screen/widgets/railway_text_field.dart';
import 'package:tsec_app/utils/railway_enum.dart';
import 'package:tsec_app/utils/station_list.dart';

class RailwayConcessionScreen extends ConsumerStatefulWidget {
  const RailwayConcessionScreen({super.key});

  @override
  ConsumerState<RailwayConcessionScreen> createState() =>
      _RailwayConcessionScreenState();
}

class _RailwayConcessionScreenState
    extends ConsumerState<RailwayConcessionScreen> {
  // final _popupCustomValidationKey = GlobalKey<DropdownSearchState<int>>();
  String? status;
  String? statusMessage;
  String? duration;
  DateTime? lastPassIssued;
  String? from;
  String? to;

  bool canIssuePass(ConcessionDetailsModel? concessionDetails,
      DateTime? lastPassIssued, String? duration) {
    if (concessionDetails?.status != null) {
      //user has applied for concession before

      // allow him to apply again if he was rejected
      if (concessionDetails!.status == ConcessionStatus.rejected) return true;

      // dont allow him to apply if his application is being processed
      if (concessionDetails.status == ConcessionStatus.unserviced) return false;

      //check date difference(only if status is serviced or downloaded)
      if (lastPassIssued == null) return true;
      DateTime today = DateTime.now();
      DateTime lastPass = lastPassIssued;
      int diff = today.difference(lastPass).inDays;
      bool retVal = (duration == "Monthly" && diff >= 30) ||
          (duration == "Quarterly" && diff >= 90);
      // debugPrint(retVal.toString());
      // debugPrint(status);
      return retVal;
    } else {
      //user has never applied for concession
      return true;
    }
  }

  String futurePassMessage(concessionDetails) {
    if (canIssuePass(concessionDetails, lastPassIssued, duration)) {
      return "⚠️ You can tap above to apply for the Pass";
    }

    if (lastPassIssued == null) {
      return "⚠️ You need to wait until your request is granted";
    }

    DateTime today = DateTime.now();
    DateTime lastPass = lastPassIssued ?? DateTime.now();
    DateTime futurePass = lastPass.add(duration == "Monthly" ? const Duration(days: 27) : const Duration(days: 87));
    int diff = futurePass.difference(today).inDays;

    return "⚠️ You will be able to apply for a new pass only after $diff days";
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchConcessionDetails();
    if (status == "rejected") {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        //     duration: Duration(milliseconds: 7000),
        //     content: Text(
        //         "Your concession service request has been rejected: $statusMessage")));
      });
    }
  }

  // String firstName = "";
  TextEditingController firstNameController = TextEditingController();

  // String middleName = "";
  TextEditingController middleNameController = TextEditingController();

  // String lastName = "";
  TextEditingController lastNameController = TextEditingController();

  // String dateofbirth = "";
  String _ageYears = "";
  String _ageMonths = "";

  // String _age = "";
  // String phoneNum = "";
  TextEditingController phoneNumController = TextEditingController();

  // String? duration;
  String? gender;
  String? travelLane;
  String? travelClass;

  // String address = "";
  TextEditingController addressController = TextEditingController();
  String homeStation = "";
  String toStation = "Bandra";
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  // TextEditingController homeStationController = TextEditingController();
  // TextEditingController toStationController = TextEditingController();
  // String toStation = "BANDRA";

  ScrollController listScrollController = ScrollController();

  String previousPassURL = "";
  String idCardURL = "";

  final _formKey = GlobalKey<FormState>();

  bool isValidPhoneNumber(String phoneNumber) {
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    return phoneRegex.hasMatch(phoneNumber);
  }

  DateTime? _selectedDate;

  void calculateAge(DateTime dob) {
    DateTime currentDate = DateTime.now();
    int years = currentDate.year - dob.year;
    int months = currentDate.month - dob.month;
    if (currentDate.day < dob.day) {
      months--;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    setState(() {
      _ageMonths = months.toString();
      _ageYears = years.toString();
      ageController.text = "$_ageYears years $_ageMonths months";
      // debugPrint("updated ${ageController.text} ${dateOfBirthController.text}");
    });
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // dateOfBirthController.text = picked.toLocal().toString().split(' ')[0];
        dateOfBirthController.text = DateFormat('dd MMM yyyy').format(picked);
        calculateAge(picked);
      });
    }
  }

  List<String> travelLanelist = ['Western', 'Central', 'Harbour'];
  List<String> travelClassList = ['I', 'II'];
  List<String> travelDurationList = ['Monthly', 'Quarterly'];
  List<String> genderList = ['Male', 'Female'];

  File? idCardPhoto;
  File? idCardPhotoTemp;
  File? previousPassPhoto;
  File? previousPassPhotoTemp;

  void pickImage(String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        if (type == 'ID Card Photo') {
          // idCardPhoto = File(pickedFile.path);
          idCardPhotoTemp = File(pickedFile.path);
        } else if (type == 'Previous Pass Photo') {
          // previousPassPhoto = File(pickedFile.path);
          previousPassPhotoTemp = File(pickedFile.path);
        }
      });
    }
  }

  Future getImageFileFromNetwork(String url, String type) async {
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Uint8List bytes = response.bodyBytes;

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;

      final String fileName =
          DateTime.now().millisecondsSinceEpoch.toString() + '.png';

      File imageFile = File('$tempPath/$fileName');
      await imageFile.writeAsBytes(bytes);

      if (type == "idCard") {
        setState(() {
          idCardPhoto = imageFile;
          idCardPhotoTemp = imageFile;
        });
      } else {
        setState(() {
          previousPassPhoto = imageFile;
          previousPassPhotoTemp = imageFile;
        });
      }
    } else {
      throw Exception('Failed to load image from network');
    }
  }

  void cancelSelection(String type) {
    setState(() {
      if (type == 'ID Card Photo') {
        idCardPhotoTemp = null;
      } else if (type == 'Previous Pass Photo') {
        previousPassPhotoTemp = null;
      }
    });
  }

  void fetchConcessionDetails() async {
    ConcessionDetailsModel? concessionDetails =
        ref.watch(concessionDetailsProvider);

    // debugPrint(
    //     "fetched concession details in railway concession UI: $concessionDetails");
    // debugPrint("over here ${concessionDetails?.firstName}");
    if (concessionDetails != null) {
      firstNameController.text = concessionDetails.firstName;
      middleNameController.text = concessionDetails.middleName;
      lastNameController.text = concessionDetails.lastName;
      _selectedDate = concessionDetails.dob;
      dateOfBirthController.text = concessionDetails.dob != null
          ? DateFormat('dd MMM yyyy').format(concessionDetails.dob!)
          : "";
      _ageYears = concessionDetails.ageYears.toString();
      _ageMonths = concessionDetails.ageMonths.toString();
      ageController.text =
          "${concessionDetails.ageYears} years ${concessionDetails.ageMonths} months";
      // debugPrint(
      //     "fetched: ${dateOfBirthController.text} ${ageController.text}");
      phoneNumController.text = concessionDetails.phoneNum.toString();
      travelClass = concessionDetails.type;
      addressController.text = concessionDetails.address;
      duration = concessionDetails.duration;
      // toStation = concessionDetails.to;
      // toStation = "Bandra";
      homeStation = concessionDetails.from;
      gender = concessionDetails.gender;
      travelLane = concessionDetails.travelLane;
      idCardURL = concessionDetails.idCardURL;
      previousPassURL = concessionDetails.previousPassURL;
      getImageFileFromNetwork(concessionDetails.idCardURL, "idCard");
      getImageFileFromNetwork(
          concessionDetails.previousPassURL, "previousPass");
      //handle images

      status = concessionDetails.status;
      statusMessage = concessionDetails.statusMessage;
      lastPassIssued = concessionDetails.lastPassIssued;
      duration = concessionDetails.duration;
    }
  }

  void clearValues() {
    /*if (!_formKey.currentState!.validate()) {
      print("HELLO");
      return;
    }*/
    ConcessionDetailsModel? concessionDetails =
        ref.watch(concessionDetailsProvider);
    firstNameController.text = concessionDetails?.firstName ?? "";
    middleNameController.text = concessionDetails?.middleName ?? "";
    lastNameController.text = concessionDetails?.lastName ?? "";
    addressController.text = concessionDetails?.address ?? "";
    phoneNumController.text = concessionDetails?.phoneNum.toString() ?? "";
    dateOfBirthController.text = concessionDetails?.dob != null
        ? DateFormat('dd MMM yyyy').format(concessionDetails!.dob!)
        : "";
    travelLane = concessionDetails?.travelLane ?? "Western";
    gender = concessionDetails?.gender ?? "Male";
    travelClass = concessionDetails?.type ?? "II";
    duration = concessionDetails?.duration ?? "Monthly";
    travelLane = concessionDetails?.travelLane ?? "Western";
    // toStation = concessionDetails?.to ?? "";
    homeStation = concessionDetails?.from ?? "";
    idCardPhotoTemp = idCardPhoto;
    previousPassPhotoTemp = previousPassPhoto;

    ref.read(railwayConcessionOpenProvider.state).state = false;
  }

  Future saveChanges(WidgetRef ref) async {
    StudentModel student = ref.watch(userModelProvider)!.studentModel!;

    ConcessionDetailsModel details = ConcessionDetailsModel(
      status: ConcessionStatus.unserviced,
      statusMessage: "",
      ageMonths: int.parse(_ageMonths),
      ageYears: int.parse(_ageYears),
      duration: duration ?? "Monthly",
      branch: student.branch,
      gender: gender ?? "Male",
      firstName: firstNameController.text,
      gradyear: student.gradyear,
      middleName: middleNameController.text,
      lastName: lastNameController.text,
      idCardURL: idCardURL,
      previousPassURL: previousPassURL,
      from: homeStation,
      to: toStation,
      lastPassIssued: null,
      address: addressController.text,
      dob: _selectedDate ?? DateTime.now(),
      phoneNum: int.parse(phoneNumController.text),
      travelLane: travelLane ?? "Central",
      type: travelClass ?? "I",
    );

    if (_formKey.currentState!.validate() &&
        idCardPhotoTemp != null &&
        previousPassPhotoTemp != null) {
      idCardPhoto = idCardPhotoTemp;
      previousPassPhoto = previousPassPhotoTemp;

      ref.read(railwayConcessionOpenProvider.state).state = false;
      // await ref
      //     .watch(concessionProvider.notifier)
      //     .applyConcession(details, idCardPhoto!, previousPassPhoto!, context);
    } else if (idCardPhotoTemp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please add the photo of your ID card")),
      );
    } else if (previousPassPhotoTemp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please add the photo of your previous pass")),
      );
    }
  }

  Widget buildImagePicker(String type, File? selectedPhoto, bool editMode) {
    // File? selectedFile =
    //     type == 'ID Card Photo' ? idCardPhoto : previousPassPhoto;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$type',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 8),
          selectedPhoto == null
              ? OutlinedButton(
                  onPressed: () => pickImage(type),
                  child: Text('Choose Photo'),
                )
              : Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            image: DecorationImage(
                              image: FileImage(selectedPhoto),
                              fit: BoxFit.cover,
                            ),
                          ),
                          // h = 150, w = 200
                          height: MediaQuery.of(context).size.height * 0.17,
                          width: MediaQuery.of(context).size.width * 0.50,
                        ),
                        editMode
                            ? Positioned(
                                top: -8,
                                right: -8,
                                child: IconButton(
                                  icon: Icon(Icons.cancel, color: Colors.white),
                                  onPressed: () => cancelSelection(type),
                                ),
                              )
                            : Container(),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }


  void initState() {
    super.initState();

    // Fetch data once when the page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(concessionProvider.notifier).getConcessionData();
      ref.read(concessionRequestProvider.notifier).getConcessionRequestData();
    });
  }



  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    bool editMode = ref.watch(railwayConcessionOpenProvider);
    ConcessionDetailsModel? concessionDetails = ref.watch(concessionDetailsProvider);
    ConcessionRequestModel? concessionRequestData = ref.watch(concessionRequestDetailProvider);
    String formattedDate = lastPassIssued != null
        ? DateFormat('dd/MM/yyyy').format(lastPassIssued!)
        : '';

    return SingleChildScrollView(
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            StatusStepper(concessionStatus: concessionDetails?.status == null ? "" : concessionDetails!.status),
            SizedBox(height: 10),
            Container(
              width: size.width * 0.7,
              child: InkWell(
                splashFactory: NoSplash.splashFactory,
                splashColor: Colors.transparent,
                onTap: () {
                  if (canIssuePass(concessionDetails, lastPassIssued, duration)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RailwayForm(),
                      ),
                    );
                  }
                },
                child: ConcessionStatusModal(
                  canIssuePass: canIssuePass,
                  futurePassMessage: futurePassMessage,
                ),
              ),
            ),
            SizedBox(
              height: 15,
            ),
            Container(
              width: size.width * 0.9,
              alignment: Alignment.center,
              child: Text(
                "${futurePassMessage(concessionDetails)}",
                style: TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
            SizedBox(
              height: 15,
            ),
            if (concessionDetails?.status != null && (concessionDetails!.status == 'serviced' || concessionDetails!.status == 'unserviced'))
              Container(
                width: size.width * 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      "Ongoing Pass",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(10),
                      width: MediaQuery.of(context).size.width * 0.9,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blue,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          concessionDetails.status != "unserviced" ? Text(
                              "Certificate Num: ${concessionRequestData != null
                                  ? concessionRequestData.passNum
                                  : "not assigned"}",
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white),
                            ) : SizedBox(),
                          concessionDetails.status != "unserviced" ? SizedBox(
                              height: 15,
                            ) : SizedBox(),
                          concessionDetails.status != "unserviced" ? Text(
                              "Date of Issue: $formattedDate",
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white),
                            ) : SizedBox(),
                          concessionDetails.status != "unserviced" ? SizedBox(
                              height: 15,
                            ) : SizedBox(),
                          Text(
                            "Travel Lane: ${travelLane}",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "From: ${homeStation}",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          Text(
                            "To: ${toStation}",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          SizedBox(
                            height: 15,
                          ),
                          Text(
                            "Duration: ${duration}",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          Text(
                            "Class: ${travelClass}",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: size.width * 0.8,
                height: size.height*0.3,
                alignment: Alignment.center,
                child: Text(
                  "You Dont have any ongoing pass",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
