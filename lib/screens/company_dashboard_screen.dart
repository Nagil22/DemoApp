import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CompanyDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;

  const CompanyDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  CompanyDashboardScreenState createState() => CompanyDashboardScreenState();
}

class CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = false;
  List<QueryDocumentSnapshot> _meetings = [];
  final Map<DateTime, List<Color>> _events = {};

  @override
  void initState() {
    super.initState();
    _getMeetingsForDay(_focusedDay);
  }

  Future<void> _getMeetingsForDay(DateTime day) async {
    setState(() {
      _isLoading = true;
    });

    var start = DateTime(day.year, day.month, day.day);
    var end = start.add(const Duration(days: 1));
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('meetings')
          .where('userId', isEqualTo: widget.userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      setState(() {
        _meetings = snapshot.docs;
        _isLoading = false;
        _events[start] = snapshot.docs.map((doc) => Color(doc['color'])).toList();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching meetings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Company Dashboard'),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // Handle notifications
              },
            ),
          ],
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.blue[700],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.yellow[700]
                  : Colors.grey[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                title: Text(
                  'Welcome, ${widget.username}!',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Company Overview',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            eventLoader: (day) {
              return _events[day] ?? [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _getMeetingsForDay(selectedDay);
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 10),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _selectedDay != null && _meetings.isEmpty
              ? const Center(
            child: Text('No meetings for this day.'),
          )
              : Expanded(
            child: ListView.builder(
              itemCount: _meetings.length,
              itemBuilder: (context, index) {
                var meeting = _meetings[index];
                var date =
                (meeting['date'] as Timestamp).toDate();
                var formattedDate =
                DateFormat('h:mm a').format(date);

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: ListTile(
                    title: Text(meeting['title']),
                    subtitle: Text(formattedDate),
                    trailing: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(meeting['color']),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () {
                      // Handle meeting tap, e.g., show details
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.black,
          borderRadius: BorderRadius.circular(25.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: '',
            ),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushNamed(context, '/home');
                break;
              case 1:
                Navigator.pushNamed(context, '/business');
                break;
              case 2:
                Navigator.pushNamed(context, '/profile');
                break;
              case 3:
                Navigator.pushNamed(context, '/settings');
                break;
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _addMeeting(context);
        },
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.blue[700],
        child: Icon(
          Icons.add,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.black,
        ),
      ),
    );
  }

  void _addMeeting(BuildContext context) {
    String title = '';
    DateTime date = _selectedDay ?? DateTime.now();
    int color = Colors.blue.value;
    final TextEditingController dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm').format(date),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Meeting'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Title'),
                onChanged: (value) {
                  title = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(hintText: 'Date and Time'),
                controller: dateController,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );

                  if (pickedDate != null) {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(date),
                    );

                    if (pickedTime != null) {
                      setState(() {
                        date = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        dateController.text =
                            DateFormat('yyyy-MM-dd HH:mm').format(date);
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: Colors.primaries.take(6).map((colorValue) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        color = colorValue.value;
                      });
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colorValue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == colorValue.value
                              ? Colors.black
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('meetings').add({
                  'userId': widget.userId,
                  'title': title,
                  'date': Timestamp.fromDate(date),
                  'color': color,
                });
                Navigator.of(context).pop();
                _getMeetingsForDay(date);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
