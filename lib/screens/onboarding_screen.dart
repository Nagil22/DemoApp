import 'package:demo/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({Key? key}) : super(key: key);

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();

}
class _OnBoardingScreenState extends State<OnBoardingScreen>{
  late PageController _pageController;

  int _pageIndex = 0;

  @override
  void initState(){
    _pageController = PageController(initialPage: 0);
    super.initState();
  }
  @override
  void dispose(){
    _pageController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                  child: PageView.builder(
                      itemCount: demo_data.length,
                      controller: _pageController,
                      onPageChanged: (index){
                        setState(() {
                          _pageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) => OnBoardContent(
                        image: demo_data[index].image,
                        title: demo_data[index].title,
                        description: demo_data[index].description,
                      )
                  )
              ),
              Row(
                children: [
                  ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _pageIndex = 2;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 15.0
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                  child: const Text(
                      "SKIP",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black)
                    ),
                  ),
                  const Spacer(),
                  ...List.generate(
                    demo_data.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: DotIndicator(isActive: index == _pageIndex),
                        )
                    , ),
                  const Spacer(),
                  SizedBox(
                    height: 60,
                    width:  90,
                    child: ElevatedButton(
                      onPressed: () {
                        _pageIndex == 2 ? onDone(context) : _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                      child: _pageIndex == 2 ? const Text(
                          "DONE",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white)
                      ) : const Text(
                          "NEXT",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white)
                      )
                    ),
                  ),
                ],
              )
            ],
          )
        )

      )
    );
  }
}

class DotIndicator extends StatelessWidget{
  const DotIndicator({
    Key? key,
    this.isActive = false,
}) : super(key: key);

  final bool isActive;

  @override
  Widget build(BuildContext context){
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isActive ? 12 : 6,
      width: 4,
      decoration:  BoxDecoration(
        color:  isActive ? Colors.blue : Colors.blue.withOpacity(0.4),
          borderRadius: const BorderRadius.all(Radius.circular(12))
      ),
    );
  }
}

void onDone(context) async{
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('ON_BOARDING', false);
  Navigator.pushReplacement(context,
    MaterialPageRoute(builder: (context) => const LoginScreen()
  ));
}
class Onboard {
  final String image, title, description;

  Onboard({
    required this.image,
    required this.title,
    required this.description,
});
}

final List<Onboard> demo_data=[
  Onboard(
    image: "assets/illustrations/onboarding1.png",
    title: "Add and track events effortlessly",
    description: "Never miss an important date again?,\nfor tracking school grades and communication",
  ),
  Onboard(
    image: "assets/illustrations/onboarding3.png",
    title: "Never miss an important date again!",
    description: "Never miss an important date again?,\nfor tracking school grades and communication",
  ),
  Onboard(
    image: "assets/illustrations/onboarding2.png",
    title: "Centralized Communication",
    description: "Streamlines the process of sending notifications and updates, ensuring timely and effective communication.",
  ),
];

class OnBoardContent extends StatelessWidget{
  const OnBoardContent({
    Key? key,
    required this.image,
    required this.title,
    required this.description,
}): super(key: key);

  final String image, title, description;

  @override
  Widget build(BuildContext context){
    return Column(
      children: [
        const Spacer(),
        Image.asset(
            image,
            height:250
        ),
        const Spacer(),
        Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(fontWeight: FontWeight.w500)
        ),
        const SizedBox(height: 16),
        Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w300)
        ),
        const Spacer()
      ],
    );
  }
}