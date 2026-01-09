// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:fruitsofspirit/controllers/home_controller.dart';
// import 'package:fruitsofspirit/utils/responsive_helper.dart';
// import 'package:video_player/video_player.dart';
//
// class HomeScreen extends GetView<HomeController> {
//   const HomeScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: Image.asset(
//           'assets/images/logo 1.png',
//           height: ResponsiveHelper.imageHeight(context, mobile: 40),
//         ),
//         centerTitle: false,
//         actions: [
//           IconButton(
//             icon: Icon(
//               Icons.search,
//               color: const Color(0xFF87CEEB),
//               size: ResponsiveHelper.iconSize(context, mobile: 24),
//             ), // Light blue search icon
//             onPressed: () {},
//           ),
//           IconButton(
//             icon: Image.asset(
//               'assets/images/notification.png',
//               height: ResponsiveHelper.iconSize(context, mobile: 20),
//             ), // Black notification icon
//             onPressed: () {},
//           ),
//           Padding(
//             padding: EdgeInsets.only(right: ResponsiveHelper.spacing(context, 15)),
//             child: CircleAvatar(
//               radius: ResponsiveHelper.borderRadius(context, mobile: 20),
//               backgroundColor: const Color(
//                 0xFFFEECE2,
//               ), // Light peach/orange background for avatar
//               child: Icon(
//                 Icons.person,
//                 color: const Color(0xFF8B4513),
//                 size: ResponsiveHelper.iconSize(context, mobile: 24),
//               ), // Brown person icon
//             ),
//           ),
//         ],
//       ),
//       body: SafeArea(
//         top: false,
//         bottom: true,
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//             Padding(
//               padding: ResponsiveHelper.safePadding(context, horizontal: 10, vertical: 10),
//               child: Container(
//                 padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 10)),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFFF3E0), // Light orange background
//                   borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
//                   border: Border.all(
//                     color: const Color(0xFFFDD835),
//                     width: ResponsiveHelper.spacing(context, 1),
//                   ), // Light yellow/orange border
//                     boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.2),
//                       spreadRadius: ResponsiveHelper.spacing(context, 1),
//                       blurRadius: ResponsiveHelper.spacing(context, 3),
//                       offset: Offset(0, ResponsiveHelper.spacing(context, 2)), // changes position of shadow
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons
//                           .sentiment_satisfied_alt, // Placeholder icon for orange.png
//                       color: Colors.orange, // Color for the icon
//                       size: ResponsiveHelper.iconSize(context, mobile: 24),
//                     ),
//                     SizedBox(width: ResponsiveHelper.spacing(context, 10)),
//                     Expanded(
//                       child: Text(
//                         'How do you feel today?',
//                         style: ResponsiveHelper.textStyle(
//                           context,
//                           fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
//                           color: Colors.grey[700],
//                           fontWeight: FontWeight.w500,
//                         ),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     const Spacer(),
//                     ElevatedButton(
//                       onPressed: () {},
//                       style: ResponsiveHelper.adaptiveButtonStyle(
//                         context,
//                         backgroundColor: const Color(0xFFFFD1DC),
//                         foregroundColor: Colors.redAccent,
//                       ).copyWith(
//                         shape: MaterialStateProperty.all(
//                           RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
//                             side: BorderSide(
//                               color: const Color(0xFFF08080),
//                               width: ResponsiveHelper.spacing(context, 1),
//                             ), // Light coral border
//                           ),
//                         ),
//                         padding: MaterialStateProperty.all(
//                           EdgeInsets.symmetric(
//                             horizontal: ResponsiveHelper.spacing(context, 8),
//                             vertical: ResponsiveHelper.spacing(context, 4),
//                           ),
//                         ),
//                         minimumSize: MaterialStateProperty.all(
//                           Size(0, ResponsiveHelper.buttonHeight(context, mobile: 35)),
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.shopping_cart, // Shopping cart icon
//                             color: Colors.redAccent, // Color for the icon
//                             size: ResponsiveHelper.iconSize(context, mobile: 16),
//                           ),
//                           SizedBox(width: ResponsiveHelper.spacing(context, 3)),
//                           Text(
//                             'Buy Now',
//                             style: ResponsiveHelper.textStyle(
//                               context,
//                               fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//                               color: Colors.redAccent,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Quick Actions Section
//             Padding(
//               padding: ResponsiveHelper.safePadding(context, horizontal: 16),
//               child: Text(
//                 'Quick Actions',
//                 style: ResponsiveHelper.textStyle(
//                   context,
//                   fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 26, desktop: 30),
//                   fontWeight: FontWeight.bold,
//                   color: const Color(0xFF8B4513),
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 10)),
//             Padding(
//               padding: ResponsiveHelper.safePadding(context, horizontal: 16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _buildQuickActionButton(context,
//                     'assets/images/Pray.png',
//                     'Prayer Request',
//                   ),
//                   SizedBox(width: ResponsiveHelper.spacing(context, 10)),
//                   _buildQuickActionButton(context,
//                     'assets/images/User Groups.png',
//                     'Bloggers',
//                   ),
//                   SizedBox(width: ResponsiveHelper.spacing(context, 10)),
//                   _buildQuickActionButton(context,
//                     'assets/images/Strawberry.png',
//                     'Fruit of the Spirit',
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Dashboard Feed Section
//             Padding(
//               padding: ResponsiveHelper.safePadding(context, horizontal: 16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Dashboard Feed',
//                     style: ResponsiveHelper.textStyle(
//                       context,
//                       fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 26, desktop: 30),
//                       fontWeight: FontWeight.bold,
//                       color: const Color(0xFF8B4513),
//                     ),
//                   ),
//                   Icon(
//                     Icons.favorite_border,
//                     color: Colors.grey,
//                     size: ResponsiveHelper.iconSize(context, mobile: 20),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 10)),
//             Padding(
//               padding: ResponsiveHelper.safePadding(context, horizontal: 16),
//               child: Container(
//                 padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
//                 decoration: BoxDecoration(
//                   color: const Color(
//                     0xFFE8F5E9,
//                   ), // Light green background
//                   borderRadius: BorderRadius.circular(
//                     ResponsiveHelper.spacing(context, 5),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       radius: ResponsiveHelper.borderRadius(context, mobile: 20),
//                       backgroundColor: Colors.blueGrey,
//                       child: Icon(
//                         Icons.person,
//                         color: Colors.white,
//                         size: ResponsiveHelper.iconSize(context, mobile: 18),
//                       ),
//                     ),
//                     SizedBox(width: ResponsiveHelper.spacing(context, 5)),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Prayer Request',
//                             style: ResponsiveHelper.textStyle(
//                               context,
//                               fontWeight: FontWeight.bold,
//                               fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
//                               color: const Color(0xFF8B4513),
//                             ),
//                           ),
//                           SizedBox(height: ResponsiveHelper.spacing(context, 4)),
//                           Text(
//                             'Sister Mary R. needs healing: "Please pray for my recovery..."',
//                             style: ResponsiveHelper.textStyle(
//                               context,
//                               fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 17, desktop: 19),
//                               color: Colors.grey[700],
//                             ),
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
//                     SizedBox(width: ResponsiveHelper.spacing(context, 5)),
//                     ElevatedButton(
//                       onPressed: () {},
//                       style: ResponsiveHelper.adaptiveButtonStyle(
//                         context,
//                         backgroundColor: const Color(0xFF6B8E23),
//                         foregroundColor: Colors.white,
//                       ).copyWith(
//                         shape: MaterialStateProperty.all(
//                           RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(
//                               ResponsiveHelper.spacing(context, 4),
//                             ),
//                           ),
//                         ),
//                         padding: MaterialStateProperty.all(
//                           EdgeInsets.symmetric(
//                             horizontal: ResponsiveHelper.spacing(context, 10),
//                             vertical: ResponsiveHelper.spacing(context, 5),
//                           ),
//                         ),
//                         minimumSize: MaterialStateProperty.all(
//                           Size(0, ResponsiveHelper.buttonHeight(context, mobile: 40)),
//                         ),
//                       ),
//                       child: Text(
//                         'View All',
//                         style: ResponsiveHelper.textStyle(
//                           context,
//                           color: Colors.white,
//                           fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Video Section
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: ResponsiveHelper.spacing(context, 16),
//               ),
//               child: Container(
//                 height: ResponsiveHelper.imageHeight(context, mobile: 200),
//                 decoration: BoxDecoration(
//                   color: Colors.black,
//                   borderRadius: BorderRadius.circular(
//                     ResponsiveHelper.spacing(context, 5),
//                   ),
//                   image: const DecorationImage(
//                     image: AssetImage(
//                       'assets/images/videothumbnail.png',
//                     ), // Placeholder
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//                 child: Center(
//                   child: Icon(
//                     Icons.play_circle_fill,
//                     color: Colors.white.withOpacity(0.8),
//                     size: ResponsiveHelper.iconSize(context, mobile: 40),
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // The Power of Forgiveness Section
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: ResponsiveHelper.spacing(context, 16),
//               ),
//               child: Container(
//                 padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFFF8E1),
//                   borderRadius: BorderRadius.circular(
//                     ResponsiveHelper.spacing(context, 5),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       radius: ResponsiveHelper.borderRadius(context, mobile: 20),
//                       backgroundColor: Colors.brown,
//                       child: Icon(
//                         Icons.handshake,
//                         color: Colors.white,
//                         size: ResponsiveHelper.iconSize(context, mobile: 18),
//                       ),
//                     ),
//                     SizedBox(width: ResponsiveHelper.spacing(context, 5)),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'The Power of Forgiveness',
//                             style: ResponsiveHelper.textStyle(
//                               context,
//                               fontWeight: FontWeight.bold,
//                               fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
//                               color: const Color(0xFF8B4513),
//                             ),
//                           ),
//                           SizedBox(height: ResponsiveHelper.spacing(context, 4)),
//                           Text(
//                             'David Chen - Approved Blogger',
//                             style: ResponsiveHelper.textStyle(
//                               context,
//                               fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 17, desktop: 19),
//                               color: Colors.grey[700],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Icon(
//                       Icons.emoji_emotions,
//                       color: Colors.amber,
//                       size: ResponsiveHelper.iconSize(context, mobile: 20),
//                     ),
//                     SizedBox(width: ResponsiveHelper.spacing(context, 3)),
//                     Icon(
//                       Icons.thumb_up,
//                       color: Colors.blue,
//                       size: ResponsiveHelper.iconSize(context, mobile: 20),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Nine Fruit of the Spirit Section
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: ResponsiveHelper.spacing(context, 16),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '"Connect. Pray. Share.\nGrow Spiritually."',
//                         style: ResponsiveHelper.textStyle(
//                           context,
//                           fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
//                           fontWeight: FontWeight.bold,
//                           color: const Color(0xFF8B4513),
//                         ),
//                       ),
//                       SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//                       ElevatedButton(
//                         onPressed: () {
//                           // TODO: Implement Go Live functionality
//                         },
//                         style: ResponsiveHelper.adaptiveButtonStyle(
//                           context,
//                           backgroundColor: const Color(0xFFA5D6A7),
//                           foregroundColor: Colors.white,
//                         ).copyWith(
//                           padding: MaterialStateProperty.all(
//                             EdgeInsets.symmetric(
//                               horizontal: ResponsiveHelper.spacing(context, 20),
//                               vertical: ResponsiveHelper.spacing(context, 8),
//                             ),
//                           ),
//                           shape: MaterialStateProperty.all(
//                             RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
//                             ),
//                           ),
//                           minimumSize: MaterialStateProperty.all(
//                             Size(0, ResponsiveHelper.buttonHeight(context, mobile: 40)),
//                           ),
//                         ),
//                         child: Text(
//                           'Go Live',
//                           style: ResponsiveHelper.textStyle(
//                             context,
//                             fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   Image.asset(
//                     'assets/images/dove.png',
//                     height: ResponsiveHelper.imageHeight(context, mobile: 150),
//                     errorBuilder: (context, error, stackTrace) {
//                       return Icon(
//                         Icons.favorite,
//                         size: ResponsiveHelper.iconSize(context, mobile: 50),
//                         color: Colors.orange,
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Share & Read Stories Section
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: ResponsiveHelper.spacing(context, 16),
//               ),
//               child: Text(
//                 'Share & Read Stories',
//                 style: ResponsiveHelper.textStyle(
//                   context,
//                   fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 26, desktop: 30),
//                   fontWeight: FontWeight.bold,
//                   color: const Color(0xFF8B4513),
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 10)),
//             SizedBox(
//               height: ResponsiveHelper.imageHeight(context, mobile: 150),
//               child: ListView(
//                 scrollDirection: Axis.horizontal,
//                 padding: EdgeInsets.symmetric(
//                   horizontal: ResponsiveHelper.spacing(context, 16),
//                 ),
//                 children: [
//                   _buildStoryCard(context,
//                     'assets/Vector.png',
//                     'Prayer walk',
//                     '128',
//                   ),
//                   SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//                   _buildStoryCard(context,
//                     'assets/Frame.png',
//                     'Noah',
//                     '64',
//                   ),
//                   SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//                   _buildStoryCard(context,
//                     'assets/Vectorser.png',
//                     'Selah',
//                     '99',
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Connect. Pray. Share. Grow Spiritually. Section
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: ResponsiveHelper.spacing(context, 16),
//               ),
//               child: Container(
//                 padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFFF8E1),
//                   borderRadius: BorderRadius.circular(
//                     ResponsiveHelper.spacing(context, 5),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             '"Connect. Pray. Share.\nGrow Spiritually."',
//                             style: ResponsiveHelper.textStyle(
//                               context,
//                               fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
//                               fontWeight: FontWeight.bold,
//                               color: const Color(0xFF8B4513),
//                             ),
//                           ),
//                           SizedBox(height: ResponsiveHelper.spacing(context, 10)),
//                           ElevatedButton(
//                             onPressed: () {},
//                             style: ResponsiveHelper.adaptiveButtonStyle(
//                               context,
//                               backgroundColor: const Color(0xFF6B8E23),
//                               foregroundColor: Colors.white,
//                             ).copyWith(
//                               shape: MaterialStateProperty.all(
//                                 RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(
//                                     ResponsiveHelper.spacing(context, 4),
//                                   ),
//                                 ),
//                               ),
//                               padding: MaterialStateProperty.all(
//                                 EdgeInsets.symmetric(
//                                   horizontal: ResponsiveHelper.spacing(context, 16),
//                                   vertical: ResponsiveHelper.spacing(context, 5),
//                                 ),
//                               ),
//                               minimumSize: MaterialStateProperty.all(
//                                 Size(0, ResponsiveHelper.buttonHeight(context, mobile: 40)),
//                               ),
//                             ),
//                             child: Text(
//                               'Go Live',
//                               style: ResponsiveHelper.textStyle(
//                                 context,
//                                 color: Colors.white,
//                                 fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Image.asset(
//                       'assets/images/dove.png', // Placeholder
//                       height: ResponsiveHelper.imageHeight(context, mobile: 50),
//                       errorBuilder: (context, error, stackTrace) {
//                         return Icon(
//                           Icons.favorite,
//                           size: ResponsiveHelper.iconSize(context, mobile: 30),
//                           color: Colors.orange,
//                         );
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Live Videos Section
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: ResponsiveHelper.spacing(context, 16),
//               ),
//               child: Text(
//                 'Live Videos',
//                 style: ResponsiveHelper.textStyle(
//                   context,
//                   fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 26, desktop: 30),
//                   fontWeight: FontWeight.bold,
//                   color: const Color(0xFF8B4513),
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 10)),
//             SizedBox(
//               height: ResponsiveHelper.imageHeight(context, mobile: 150),
//               child: ListView(
//                 scrollDirection: Axis.horizontal,
//                 padding: EdgeInsets.symmetric(
//                   horizontal: ResponsiveHelper.spacing(context, 16),
//                 ),
//                 children: [
//                   _buildVideoThumbnail(
//                     'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
//                   ),
//                   SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//                   _buildVideoThumbnail(
//                     'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
//                   ),
//                   SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//                   _buildVideoThumbnail(
//                     'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//             // Share Your Testimony Button
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {},
//                 style: ResponsiveHelper.adaptiveButtonStyle(
//                   context,
//                   backgroundColor: const Color(0xFF6B8E23),
//                   foregroundColor: Colors.white,
//                 ).copyWith(
//                   shape: MaterialStateProperty.all(
//                     RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(
//                         ResponsiveHelper.spacing(context, 5),
//                       ),
//                     ),
//                   ),
//                   padding: MaterialStateProperty.all(
//                     EdgeInsets.symmetric(
//                       horizontal: ResponsiveHelper.spacing(context, 25),
//                       vertical: ResponsiveHelper.spacing(context, 8),
//                     ),
//                   ),
//                   minimumSize: MaterialStateProperty.all(
//                     Size(0, ResponsiveHelper.buttonHeight(context, mobile: 50)),
//                   ),
//                 ),
//                 child: Text(
//                   'Share Your Testimony',
//                   style: ResponsiveHelper.textStyle(
//                     context,
//                     color: Colors.white,
//                     fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.spacing(context, 20)),
//           ],
//         ),
//         ),
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: const Color(0xFF8B4513),
//         unselectedItemColor: Colors.grey,
//         selectedLabelStyle: ResponsiveHelper.textStyle(context, fontSize: ResponsiveHelper.isMobile(context) ? 12 : 14),
//         unselectedLabelStyle: ResponsiveHelper.textStyle(context, fontSize: ResponsiveHelper.isMobile(context) ? 12 : 14),
//         items: [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.home, size: ResponsiveHelper.iconSize(context, mobile: 24)),
//             label: 'Home',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.menu_book, size: ResponsiveHelper.iconSize(context, mobile: 24)),
//             label: 'Read',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.people, size: ResponsiveHelper.iconSize(context, mobile: 24)),
//             label: 'Community',
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildQuickActionButton(BuildContext context, String imagePath, String label) {
//     return Expanded(
//       child: Column(
//         children: [
//           Container(
//             width: double.infinity,
//             constraints: BoxConstraints(
//               minHeight: ResponsiveHelper.imageHeight(context, mobile: 80, tablet: 100, desktop: 120),
//             ),
//             padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
//             decoration: BoxDecoration(
//               color: const Color(0xFFFEECE2), // Light peach/orange background
//               borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.2),
//                   spreadRadius: ResponsiveHelper.spacing(context, 2),
//                   blurRadius: ResponsiveHelper.spacing(context, 5),
//                   offset: Offset(0, ResponsiveHelper.spacing(context, 3)), // changes position of shadow
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Image.asset(
//                   imagePath,
//                   height: ResponsiveHelper.imageHeight(context, mobile: 35, tablet: 45, desktop: 55),
//                   fit: BoxFit.contain,
//                   errorBuilder: (context, error, stackTrace) {
//                     return Icon(
//                       Icons.image,
//                       size: ResponsiveHelper.iconSize(context, mobile: 35, tablet: 45, desktop: 55),
//                       color: const Color(0xFF8B4513),
//                     );
//                   },
//                 ),
//                 SizedBox(height: ResponsiveHelper.spacing(context, 8)),
//                 Text(
//                   label,
//                   style: ResponsiveHelper.textStyle(
//                     context,
//                     fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
//                     color: const Color(0xFF8B4513),
//                     fontWeight: FontWeight.w600,
//                   ),
//                   textAlign: TextAlign.center,
//                   maxLines: 2,
//                   overflow: TextOverflow.visible,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFruitItem(BuildContext context, String imagePath, String label) {
//     return Column(
//       children: [
//         Image.asset(imagePath, height: ResponsiveHelper.imageHeight(context, mobile: 30)),
//         SizedBox(height: ResponsiveHelper.spacing(context, 5)),
//         Text(
//           label,
//           style: ResponsiveHelper.textStyle(
//             context,
//             fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
//             color: Colors.grey[700],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildStoryCard(BuildContext context, String imagePath, String title, String likes) {
//     return Container(
//       width: ResponsiveHelper.imageWidth(context, mobile: 150),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.2),
//             spreadRadius: ResponsiveHelper.spacing(context, 2),
//             blurRadius: ResponsiveHelper.spacing(context, 5),
//             offset: Offset(0, ResponsiveHelper.spacing(context, 3)),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           ClipRRect(
//             borderRadius: BorderRadius.vertical(
//               top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
//             ),
//             child: Image.asset(
//               imagePath,
//               height: ResponsiveHelper.imageHeight(context, mobile: 80),
//               width: double.infinity,
//               fit: BoxFit.cover,
//             ),
//           ),
//           Padding(
//             padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: ResponsiveHelper.textStyle(
//                     context,
//                     fontWeight: FontWeight.bold,
//                     fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
//                     color: const Color(0xFF8B4513),
//                   ),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 SizedBox(height: ResponsiveHelper.spacing(context, 5)),
//                 Row(
//                   children: [
//                     Text(
//                       likes,
//                       style: ResponsiveHelper.textStyle(
//                         context,
//                         fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 17, desktop: 19),
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     SizedBox(width: ResponsiveHelper.spacing(context, 3)),
//                     Icon(
//                       Icons.favorite,
//                       color: Colors.red,
//                       size: ResponsiveHelper.iconSize(context, mobile: 16),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildVideoThumbnail(String videoUrl) {
//     return _VideoPlayerThumbnail(videoUrl: videoUrl);
//   }
// }
//
// class _VideoPlayerThumbnail extends StatefulWidget {
//   final String videoUrl;
//
//   const _VideoPlayerThumbnail({Key? key, required this.videoUrl}) : super(key: key);
//
//   @override
//   _VideoPlayerThumbnailState createState() => _VideoPlayerThumbnailState();
// }
//
// class _VideoPlayerThumbnailState extends State<_VideoPlayerThumbnail> {
//   late VideoPlayerController _controller;
//   bool _isPlaying = false;
//   bool _showVideo = false; // New variable to control showing video or thumbnail
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
//       ..initialize().then((_) {
//         setState(() {});
//       });
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: ResponsiveHelper.imageWidth(context, mobile: 200),
//       decoration: BoxDecoration(
//         color: Colors.black,
//         borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
//         image: _showVideo
//             ? null
//             : const DecorationImage(
//                 image: AssetImage('assets/images/video_thumbnail.png'), // Re-added thumbnail
//                 fit: BoxFit.cover,
//               ),
//       ),
//       child: _controller.value.isInitialized
//           ? Stack(
//               alignment: Alignment.center,
//               children: [
//                 if (_showVideo) // Conditionally show VideoPlayer
//                   AspectRatio(
//                     aspectRatio: _controller.value.aspectRatio,
//                     child: VideoPlayer(_controller),
//                   ),
//                 Positioned.fill(
//                   child: Center(
//                     child: IconButton(
//                       icon: Icon(
//                         _isPlaying ? Icons.pause_circle : Icons.play_circle,
//                         color: Colors.white.withOpacity(0.8),
//                         size: ResponsiveHelper.iconSize(context, mobile: 32),
//                       ),
//                       onPressed: () {
//                         setState(() {
//                           _showVideo = true; // Show video when play is pressed
//                           _isPlaying ? _controller.pause() : _controller.play();
//                           _isPlaying = !_isPlaying;
//                         });
//                       },
//                     ),
//                   ),
//                 ),
//                 if (!_showVideo) // Show overlay text and icon only when thumbnail is visible
//                   Positioned(
//                     top: ResponsiveHelper.spacing(context, 5),
//                     left: ResponsiveHelper.spacing(context, 5),
//                     child: Container(
//                       padding: EdgeInsets.symmetric(
//                           horizontal: ResponsiveHelper.spacing(context, 4),
//                           vertical: ResponsiveHelper.spacing(context, 2)),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.6),
//                         borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 5)),
//                       ),
//                       child: Text(
//                         'Video',
//                         style: ResponsiveHelper.textStyle(
//                           context,
//                           color: Colors.white,
//                           fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                 if (!_showVideo)
//                   Positioned(
//                     bottom: ResponsiveHelper.spacing(context, 5),
//                     left: ResponsiveHelper.spacing(context, 5),
//                     child: Container(
//                       padding: EdgeInsets.symmetric(
//                           horizontal: ResponsiveHelper.spacing(context, 4),
//                           vertical: ResponsiveHelper.spacing(context, 2)),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.6),
//                         borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 5)),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.add_circle,
//                             color: Colors.green,
//                             size: ResponsiveHelper.iconSize(context, mobile: 12),
//                           ),
//                           SizedBox(width: ResponsiveHelper.spacing(context, 3)),
//                           Text(
//                             'Kindness Moment',
//                             style: ResponsiveHelper.textStyle(
//                               context,
//                               color: Colors.white,
//                               fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 if (!_showVideo)
//                   Positioned(
//                     bottom: ResponsiveHelper.spacing(context, 5),
//                     right: ResponsiveHelper.spacing(context, 5),
//                     child: CircleAvatar(
//                       radius: ResponsiveHelper.borderRadius(context, mobile: 15),
//                       backgroundColor: Colors.white.withOpacity(0.8),
//                       child: Icon(
//                         Icons.person, // Placeholder for the small icon
//                         color: Colors.brown,
//                         size: ResponsiveHelper.iconSize(context, mobile: 12),
//                       ),
//                     ),
//                   ),
//               ],
//             )
//           : Center(
//               child: CircularProgressIndicator(
//                 color: Colors.white,
//               ),
//             ),
//     );
//   }
// }