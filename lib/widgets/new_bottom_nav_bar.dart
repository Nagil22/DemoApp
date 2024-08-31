import 'package:flutter/material.dart';


class NewBottomNavBar extends StatelessWidget {

  final int currentIndex;
  final void Function(int) onTapped;
  final List<IconData> icons;
  final List<String> titles;

const NewBottomNavBar({
  super.key,
  this.currentIndex = 0,
  required this.icons,
  required this.titles,
  required this.onTapped,
});

  @override
  Widget build(BuildContext context) {
  return Container(
    height: 65,
    margin:  const EdgeInsets.only(
      right: 24,
      left: 24,
      bottom: 24,
    ),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              spreadRadius: 10
          )
        ]
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: icons.map((icon){
        int index = icons.indexOf(icon);
        bool isSelected = currentIndex == index;
        return Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: (){
              onTapped(index);
              // setState((){
              //   selectedIndex = index;
              // });
            },
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    alignment: Alignment.center,
                    margin: EdgeInsets.only(
                      top: 15,
                      bottom: 0,
                      left: icons.length > 4 ? 20 : 28,
                      right: icons.length > 4 ? 20 : 28,
                    ),
                    child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 25,),
                  ),
                  Text(
                      titles[index],
                      style: TextStyle(color: isSelected ? Colors.blue : Colors.grey, fontSize: 10)
                  ),
                  const SizedBox(
                    height: 10,
                  )
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}
}