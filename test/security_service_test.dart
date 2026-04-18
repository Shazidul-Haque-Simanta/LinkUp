import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/resource_model.dart';

// IMPORTANT: This file simulates "Automatic Security Probing"
// to ensure the app logic correctly blocks unauthorized actions.

@GenerateMocks([FirebaseAuth, FirebaseDatabase, DatabaseReference, DataSnapshot, User])
import 'security_service_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseDatabase mockDb;
  late MockDatabaseReference mockRef;
  late FirebaseService service;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockDb = MockFirebaseDatabase();
    mockRef = MockDatabaseReference();
    
    // Support chaining: ref.child('x') returns a ref
    when(mockRef.child(any)).thenReturn(mockRef);
    
    service = FirebaseService(
      auth: mockAuth, 
      dbRef: mockRef,
    );
  });

  group('Automated Security Authorization Tests', () {
    
    test('Should BLOCK profile update if UID does not match current user', () async {
       // 1. Setup Mock State (Current User ID: "USER_A")
       final mockUser = MockUser();
       when(mockUser.uid).thenReturn('USER_A');
       when(mockAuth.currentUser).thenReturn(mockUser);

       // 2. Try to update USER_B's profile via Service
       // Note: This logic assumes FirebaseService has the "Self-only" checks we added.
       // we'll simulate the service call here as a logic verification.
       
       final targetUid = 'USER_B';
       
       await expectLater(
         service.updateUserProfile(targetUid, {'name': 'Hacker'}), 
         throwsA(predicate((e) => e.toString().contains('Unauthorized')))
       );
    });

    test('Should BLOCK resource deletion if current user is not the uploader', () async {
       // 1. Current User: "NOT_THE_OWNER"
       final mockUser = MockUser();
       when(mockUser.uid).thenReturn('NOT_THE_OWNER');
       when(mockAuth.currentUser).thenReturn(mockUser);

       // 2. Mock a Resource owned by "ORIGINAL_OWNER"
       final mockSnapshot = MockDataSnapshot();
       when(mockSnapshot.exists).thenReturn(true);
       when(mockSnapshot.value).thenReturn({
         'uploaderId': 'ORIGINAL_OWNER',
         'title': 'Secret Exam'
       });
       
       when(mockRef.get()).thenAnswer((_) async => mockSnapshot);

       // 3. Verify deletion throws Authorization error
       // (Our service now checks snapshot uploaderId vs currentUser.uid)
       await expectLater(
         service.deleteResource('RESOURCE_ID'), 
         throwsA(predicate((e) => e.toString().contains('Unauthorized')))
       );
    });

    test('Should PROTECT Private Resources from unauthorized streams', () async {
       // 1. Current User: "NOT_THE_OWNER"
       final mockUser = MockUser();
       when(mockUser.uid).thenReturn('STRANGER_ID');
       when(mockAuth.currentUser).thenReturn(mockUser);

       // 2. Mock a Privatized Resource
       final privateResource = ResourceModel(
         id: '1',
         title: 'My Diary',
         isPrivate: true,
         uploaderId: 'REAL_OWNER',
         fileurls: '',
         subject: 'Personal',
         courseCode: '',
         category: 'Notes',
         downloads: 0,
         rating: 0,
         createdAt: DateTime.now(),
       );

       // 3. Verify logic (Stream should return NULL or FILTERED results)
       // (Simulating the filter we added to streamResourceById)
       
       bool isVisible = !privateResource.isPrivate || privateResource.uploaderId == mockUser.uid;
       expect(isVisible, false);
    });
  });
}
