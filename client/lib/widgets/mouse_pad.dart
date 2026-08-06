import 'dart:async';
import 'package:flutter/material.dart';


class MousePad extends StatefulWidget {

  final Function(double dx,double dy) onMove;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onMiddleClick;

  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeDown;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final Function(double dx,double dy) onDrag;

  final Function(double dy) onScroll;


  const MousePad({
    super.key,
    required this.onMove,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onMiddleClick,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDrag,
    required this.onScroll,
    required this.onSwipeUp,
    required this.onSwipeDown,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });


  @override
  State<MousePad> createState()=>_MousePadState();

}



class _MousePadState extends State<MousePad>{

  int fingers=0;
  double scrollVelocity=0;
  String mode="none";
  bool longPressed=false;
  bool dragging=false;
  bool moved=false;
  bool swipeFired=false;


  int? primaryPointer;
  Offset? startPosition;
  Timer? timer;
  Timer? tapTimer;
  Timer? momentumTimer;
  DateTime? lastMoveTime;
  DateTime? lastTapTime;
  Offset? lastTapPosition;


  void _endDragIfNeeded(){

    if(dragging){

      widget.onDragEnd();

      dragging=false;

    }

  }

  void _handleTap(Offset position){
    
    widget.onTap();

    final now = DateTime.now();

    final isDoubleTap = lastTapTime != null &&
        now.difference(lastTapTime!) <= const Duration(milliseconds: 300) &&
        lastTapPosition != null &&
        (lastTapPosition! - startPosition!).distance < 40;

    if (isDoubleTap) {
      widget.onDoubleTap();
      lastTapTime = null;
      lastTapPosition = null;
    } else {
      lastTapTime = now;
      lastTapPosition = startPosition;
    }
  }

  void _startMomentumScroll(){
  
    const double minVelocity = 0.02;        // زیر این، متوقف می‌شه
    const double friction = 0.95;           // هر تیک ۵٪ کند می‌شه
    const Duration tick = Duration(milliseconds: 16);   // ~60fps
  
    if(scrollVelocity.abs() < minVelocity) return;
  
    momentumTimer = Timer.periodic(tick, (t){
    
      scrollVelocity *= friction;
  
      if(scrollVelocity.abs() < minVelocity){
        t.cancel();
        momentumTimer = null;
        return;
      }
  
      final dyThisTick = scrollVelocity * tick.inMilliseconds;
      widget.onScroll(dyThisTick);
  
    });
  
  }

  @override
  void dispose(){

    timer?.cancel();
    _endDragIfNeeded();
    super.dispose();

  }

  @override
  Widget build(BuildContext context){


    return Listener(


      onPointerDown: (event){
        
        momentumTimer?.cancel();
        scrollVelocity=0;

        fingers++;


        if(fingers == 1){

          debugPrint("1 finger detected");


          mode="move";
          moved=false;
          startPosition = event.position;
          primaryPointer = event.pointer;


          timer = Timer(
            const Duration(milliseconds:350),
            (){

              longPressed=true;

            },
          );


        }


        else if(fingers == 2){
          _endDragIfNeeded();
          debugPrint("2 finger detected");
          mode="scroll";
          timer?.cancel();
          longPressed=false;

        }


        else if(fingers == 3){
          _endDragIfNeeded();
          debugPrint("3 finger detected");
          mode="middle";
          timer?.cancel();
          longPressed=false;

        }



      },



      onPointerMove:(event){



        final dx=event.delta.dx;
        final dy=event.delta.dy;

        final totalDx = event.position.dx - startPosition!.dx;
        final totalDy = event.position.dy - startPosition!.dy;



        if(!moved && (totalDx.abs() > 5 || totalDy.abs() > 5)){

          moved=true;
          timer?.cancel();

        }



        switch(mode){


          case "scroll":
            if (event.pointer == primaryPointer) {
              widget.onScroll(dy);

              final now = DateTime.now();
              if (lastMoveTime != null) {
                final dtMs = now.difference(lastMoveTime!).inMilliseconds / 50.0; // Convert to seconds
                if (dtMs > 0) {
                  scrollVelocity = dy / dtMs;
                  const double maxVelocity = 1.0;
                  scrollVelocity = (scrollVelocity * 0.2 + scrollVelocity * 0.1).clamp(-maxVelocity, maxVelocity); // Apply some smoothing
                }
              }
              lastMoveTime = now;
            }
            break;



          case "middle":
            if (event.pointer == primaryPointer && !swipeFired) {
              const double swipeThreshold = 60.0; // Minimum distance to consider a swipe

              if (totalDy.abs() > swipeThreshold || totalDx.abs() > swipeThreshold) {
                
                swipeFired = true; // Prevent multiple swipes in one gesture

                if (totalDy.abs() > totalDx.abs()) {
                  if (totalDy < 0) {
                    widget.onSwipeUp();
                  } else {
                    widget.onSwipeDown();
                  }
                } else {
                  if (totalDx < 0) {
                    widget.onSwipeLeft();
                  } else {
                    widget.onSwipeRight();
                  }
                }
              }
            }
            break;



          case "move":


            if(longPressed){

              if(!dragging){
                dragging=true;
                widget.onDragStart();
              }

              widget.onDrag(dx,dy);

            }

            else{
              widget.onMove(dx,dy);
            }
            break;
        }
      },


      onPointerUp:(event){

        fingers--;

        if(fingers==0){

          timer?.cancel();

          if(mode=="middle"){// && !moved
            if (!moved){
              widget.onMiddleClick();
            }
          }



          else if(mode=="move"){


            if(longPressed && !dragging){
              widget.onLongPress();
            }


            else if(!dragging && !longPressed && !moved){
              _handleTap(event.position);
            }


          }
          else if(mode=="scroll"){

            _startMomentumScroll();

          }


          _endDragIfNeeded();
          mode="none";
          longPressed=false;
          dragging=false;
          moved=false;
          swipeFired=false;
          primaryPointer = null;
          startPosition = null;
          lastMoveTime = null;


        }



      },


      onPointerCancel:(event){
        fingers--;

        if(fingers <= 0){

          timer?.cancel();
          _endDragIfNeeded();

          fingers=0;
          mode="none";
          longPressed=false;
          dragging=false;
          moved=false;
          primaryPointer = null;
          startPosition = null;
          swipeFired=false;
        }
      },


      child: Container(
        color: Colors.transparent,
      ),


    );


  }


}
