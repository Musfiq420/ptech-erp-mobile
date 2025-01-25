import 'dart:convert';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MachineScanner extends StatefulWidget {
  const MachineScanner({super.key});

  @override
  _MachineScannerPageState createState() => _MachineScannerPageState();
}

class _MachineScannerPageState extends State<MachineScanner> {
  String? qrCodeValue;
  bool isScanning = true;
  final storage = FlutterSecureStorage();
  final securedDesignation = "designation";
  bool isScanned = false;

  Widget funcScannerBuilder() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: MobileScanner(
            onDetect: (BarcodeCapture capture) async {
              print(isScanned);
              if (capture.raw != null) {
                setState(() {
                  qrCodeValue = capture.barcodes[0].rawValue;
                  // Trigger a single vibration
                  Vibration.vibrate();
                  isScanning = !isScanning;
                });

                // if(!isScanned){
                //
                //   Vibration.vibrate();
                //   bool? result = await showDialog(
                //     context: context,
                //     barrierDismissible: false,
                //     builder: (BuildContext context){
                //       return AlertDialog(
                //         title: Text("Model: ${capture.barcodes[0].rawValue}"),
                //         content: Text("Machine description is here"),
                //         actions: [
                //           ElevatedButton(onPressed: (){}, child: Text("Yes")),
                //           ElevatedButton(onPressed: (){
                //             Navigator.of(context).pop(false);
                //             }, child: Text("Cancel"))
                //         ],
                //       );
                //     }
                // );
                //   print(result);
                //   result!? isScanned =  false: isScanned =false;
                //
                // };
              }
            },
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(
              qrCodeValue ?? 'Scan a QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<Map?> funcFetchMachineDetails(String model) async {
    final url = Uri.parse(
        "https://machine-maintenance.ddns.net/api/maintenance/machines/?machine_id=$model");

    final headers = {'Content-Type': 'application/json'};
    final response = await http.get(url);
    final designatione =
        await storage.read(key: securedDesignation) ?? "Unknown";
    if (response.statusCode == 200) {
      return jsonDecode(response.body)[0];
    }
    return null;
  }

  Widget funcMachineDetailsBuilder({required String model}) {
    return FutureBuilder(
      future: funcFetchMachineDetails(model),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: Column(
            children: [Text("Model: $model"), CircularProgressIndicator()],
          ));
        } else if (snapshot.hasData) {
          return MachineDetailsPage(
            machineDetails: snapshot.data!,
            onScanAgain: () {
              setState(() {
                isScanning = true;
              });
            },
          );
        } else {
          return Center(
            child: Column(
              children: [Text("No data Available")],
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          // actions: [
          //   ElevatedButton(
          //     onPressed: () {
          //       setState(() {
          //         isScanning = true;
          //       });
          //     },
          //     child: const Text("Scan Again"),
          //   )
          // ],
          ),
      body: isScanning
          ? funcScannerBuilder()
          : funcMachineDetailsBuilder(
              model: qrCodeValue ?? "No Model Detected"),
    );
  }
}

class MachineDetailsPage extends StatefulWidget {
  final Map machineDetails;
  final VoidCallback onScanAgain;
  const MachineDetailsPage(
      {super.key, required this.machineDetails, required this.onScanAgain});

  @override
  _MachineDetailsPageState createState() => _MachineDetailsPageState();
}

class _MachineDetailsPageState extends State<MachineDetailsPage> {
  bool isPatching = false;
  int selectedCategoryIndex = -1;
  String? selectedCategory;
  List<dynamic> problemCategories = [];
  bool isFetchingProblemCategory = true;
  List<dynamic> lines = [];
  String? successMessage;
  Map<String, dynamic> matchingLine = {};

  Future<String?> getDesignation() async {
    final storage = FlutterSecureStorage();
    final securedDesignation = "designation";
    final designation = await storage.read(key: securedDesignation);

    return designation;
  }

  @override
  void initState() {
    super.initState();
    print("initiated");
    fetchProblemCategories();
    fetchLines();
    print("fetched");

    isFetchingProblemCategory = false;
  }

  Future<void> fetchProblemCategories() async {
    final String apiUrl =
        "https://machine-maintenance.ddns.net/api/maintenance/problem-category/"; // Replace with your API URL
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          problemCategories = json.decode(response.body);
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> fetchLines() async {
    final String apiUrl =
        "https://machine-maintenance.ddns.net/api/production/lines/"; // Replace with your API URL
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        print(response.body);
        setState(() {
          lines = json.decode(response.body);
          matchingLine = lines.firstWhere(
            (line) => line['id'] == widget.machineDetails['line'],
            orElse: () => {},
          );
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final machine = widget.machineDetails;
    print(widget.machineDetails);
    final statuses = ['active', 'inactive', 'maintenance', 'broken'];
    final problemCategory = [
      'Problem Cat 1',
      'Problem Cat 2',
      'Problem Cat 3',
      'Problem Cat 4'
    ];
    final designations = [
      'Mechanic',
      'Supervisor',
      'Operator',
      'Admin Officer'
    ];
    String lastProblem = "";

    return FutureBuilder(
      future: getDesignation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else {
          final designation = snapshot.data ?? "Unknown";
          final machineStatus = machine['status'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Machine ${machine['machine_id']}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                Text(
                  "Line: ${matchingLine != {} ? matchingLine['name'] : ""}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Floor: ${matchingLine != {} ? matchingLine['floor']['name'] : ""}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Sequence: ${machine['sequence']}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text("Model Number: ${machine['model_number']}"),
                Text("Serial No: ${machine['serial_no']}"),

                Text("Status: $machineStatus"),
                Spacer(),
                // SizedBox(height: 50),
                // Display based on conditions
                if (designation == 'Supervisor' &&
                    machineStatus == 'active') ...[
                  //stage active to broken  && machineStatus == 'active'
                  successMessage == null
                      ? Text("Your Role: $designation")
                      : Spacer(),
                  successMessage == null
                      ? const Text("Is the machine broken?")
                      : Spacer(),
                  successMessage == null ? SizedBox(height: 16) : Spacer(),
                  successMessage == null
                      ? TextField(
                          decoration: InputDecoration(
                              hintText: '',
                              border: OutlineInputBorder(),
                              labelText: "Explain the problem:"),
                          onChanged: (value) {
                            lastProblem = value;
                          },
                        )
                      : Spacer(),
                  SizedBox(height: 16),
                  isPatching
                      ? CircularProgressIndicator()
                      : successMessage != null
                          ? Text("$successMessage")
                          : ElevatedButton(
                              onPressed: () {
                                final currentTIme = DateTime.now()
                                    .toUtc()
                                    .toString()
                                    .split('.')
                                    .first;
                                Map body = {
                                  "status": "broken",
                                  "last_breakdown_start":
                                      currentTIme.split(" ")[0] +
                                          "T" +
                                          currentTIme.split(" ")[1] +
                                          "Z",
                                  "last_problem": lastProblem
                                };

                                print(body);
                                updateMachineStatus(
                                    machineId: machine['id'].toString(),
                                    body: body);
                              },
                              child: const Text("Set to Broken"),
                            ),
                ] else if (designation == 'Supervisor' &&
                    machineStatus == 'maintenance') ...[
                  //&& machineStatus == 'maintenance'
                  successMessage == null
                      ? Text("Your Role: $designation")
                      : Spacer(),
                  successMessage == null
                      ? const Text("Is the machine active now?")
                      : Spacer(),
                  successMessage == null
                      ? const SizedBox(height: 16.0)
                      : Spacer(),

                  problemCategories.isEmpty
                      ? CircularProgressIndicator()
                      : successMessage != null
                          ? Text("$successMessage")
                          : DropdownButton<String>(
                              value: selectedCategory,
                              hint: Text("Selected Problem Category:"),
                              items: problemCategories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category['id'].toString(),
                                  child: Text(category['name']),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedCategory = newValue;
                                  selectedCategoryIndex = int.parse(newValue!);
                                  print(selectedCategoryIndex);
                                });
                              },
                            ),
                  const SizedBox(height: 16.0),

                  isPatching
                      ? CircularProgressIndicator()
                      : successMessage != null
                          ? Text("$successMessage")
                          : ElevatedButton(
                              onPressed: () {
                                if (selectedCategoryIndex == -1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          "Category should be selected should not be 0!"),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                DateTime startTime = DateTime.parse(
                                    "${machine['last_breakdown_start']}");
                                DateTime endTime = DateTime.parse(DateTime.now()
                                        .toUtc()
                                        .toString()
                                        .split('.')
                                        .first +
                                    'Z');
                                String formattedDuration = endTime
                                    .difference(startTime)
                                    .toString()
                                    .split('.')
                                    .first;

                                Map body = {
                                  "status": "active",
                                };

                                final breakdownBody = {
                                  "breakdown_start": "$startTime",
                                  "repairing_start":
                                      "${machine['last_repairing_start'] ?? "2025-01-09T11:50:00Z"}",
                                  "lost_time": formattedDuration,
                                  "comments": "",
                                  "machine": "${machine['id']}",
                                  "mechanic": "",
                                  "operator": "",
                                  "problem_category": "$selectedCategoryIndex",
                                  "location": "1",
                                  "line": "${machine['line']}",
                                };
                                print(breakdownBody);
                                updateMachineStatus(
                                    machineId: machine['id'].toString(),
                                    body: body,
                                    willUpdateBreakdown: true,
                                    breakdownBody: breakdownBody);
                              },
                              child: const Text("Set to Active"),
                            ),
                ] else if (designation == 'Mechanic' &&
                    machineStatus == 'broken') ...[
                  //stage broken to maintenance
                  successMessage == null
                      ? Text("Your Role: $designation")
                      : Spacer(),
                  successMessage == null
                      ? const Text(
                          "Do you want to set the machine status to Maintenance?")
                      : Spacer(),
                  successMessage == null
                      ? const SizedBox(height: 16.0)
                      : Spacer(),
                  isPatching
                      ? CircularProgressIndicator()
                      : successMessage != null
                          ? Text("$successMessage")
                          : ElevatedButton(
                              onPressed: () {
                                final currentTIme = DateTime.now()
                                    .toUtc()
                                    .toString()
                                    .split('.')
                                    .first;
                                Map body = {
                                  "status": "maintenance",
                                  "last_repairing_start":
                                      currentTIme.split(" ")[0] +
                                          "T" +
                                          currentTIme.split(" ")[1] +
                                          "Z"
                                };
                                updateMachineStatus(
                                    machineId: machine['id'].toString(),
                                    body: body);
                              },
                              child: const Text("Set to Maintenance"),
                            ),
                ] else if (designation == 'Admin Officer') ...[
                  Text("Your Role: $designation"),
                  const Text("Change machine status to:"),
                  const SizedBox(height: 16.0),
                  DropdownButton<String>(
                    value: machineStatus,
                    items: statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        updateMachineStatus(machineId: machine['id'], body: {});
                      }
                    },
                  ),
                ],
                ElevatedButton(
                  onPressed: widget.onScanAgain,
                  child: const Text("Scan Again"),
                ),
              ],
            ),
          );
        }
      },
    );
  }

// Function to update the machine status
  Future<void> updateMachineStatus(
      {required String machineId,
      required Map body,
      Map breakdownBody = const {},
      bool willUpdateBreakdown = false}) async {
    final url =
        "https://machine-maintenance.ddns.net/api/maintenance/machines/$machineId/";
    final breakDownUrl =
        "https://machine-maintenance.ddns.net/api/maintenance/breakdown-logs/";

    setState(() {
      isPatching = true;
    });

    try {
      final response = await http.patch(
        Uri.parse(url),
        body: body,
      );
      print(response.body);
      print("Status updated to $body");

      if (willUpdateBreakdown) {
        final patchResponse =
            await http.post(Uri.parse(breakDownUrl), body: breakdownBody);
        print(breakdownBody);
        print("Breakdown updated ${patchResponse.body}");
        // Show success message
      } else {
        print("will not Update breaddwonLodg");
      }
      setState(() {
        isPatching = true;
        successMessage =
            "Machine status updated successfully to ${body['status']}";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Machine status updated successfully to ${body['status']}"),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print("Error: $e");
      setState(() {
        isPatching = false;
        successMessage = "An error occurred while updating status.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An error occurred while updating status."),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        isPatching = false;
      });
    }
  }
} //stagefull widget
