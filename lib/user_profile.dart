import 'dart:typed_data';
import 'demo_data.dart';
import 'marketplace.dart';

const samplePhone = '09121234567';
String normalizePhone(String value) =>
    normalizeMarketText(value).replaceAll(RegExp(r'[\s-]'), '');
bool validMobile(String value) =>
    RegExp(r'^09\d{9}$').hasMatch(normalizePhone(value));

class ProfilePhoto {
  const ProfilePhoto.asset(this.asset) : bytes = null;
  const ProfilePhoto.bytes(this.bytes) : asset = null;
  final String? asset;
  final Uint8List? bytes;
}

class UserProfile {
  UserProfile(
      {this.id = 'unassigned',
      this.phoneVerified = false,
      this.available = true,
      this.name = '',
      this.specialty = 'سازنده',
      this.activity = ActivityType.individual,
      this.city,
      this.coverage,
      this.bio = '',
      this.experience = '',
      this.availability = '',
      this.avatar,
      this.coverPhoto,
      this.complete = false,
      Iterable<String> skills = const [],
      Iterable<ProfilePhoto> photos = const []})
      : skills = Set.from(skills),
        photos = List.from(photos);
  factory UserProfile.sample() => UserProfile(
      id: 'profile-sample',
      phoneVerified: true,
      name: 'مهدی احمدی',
      city: 'مشهد',
      complete: true,
      coverage: const AreaFilter(
          province: 'خراسان رضوی', city: 'مشهد', surroundings: true),
      bio: 'اجرای پروژه‌های ساختمانی و هماهنگی اکیپ‌های اجرایی در مشهد.',
      experience: '۸ سال',
      availability: 'با هماهنگی قبلی',
      skills: ['ساخت‌وساز', 'مدیریت پروژه', 'بتن‌ریزی'],
      photos: ['concrete', 'scaffold', 'tiles', 'sand', 'survey', 'material0']
          .map(ProfilePhoto.asset));
  final String id;
  bool phoneVerified, available;
  String name, specialty, bio, experience, availability;
  String? city;
  AreaFilter? coverage;
  ActivityType activity;
  Uint8List? avatar;
  ProfilePhoto? coverPhoto;
  bool complete;
  final Set<String> skills;
  final List<ProfilePhoto> photos;
  ProviderProfile get badge => ProviderProfile(specialty, activity,
      identity: phoneVerified
          ? IdentityStatus.demoVerified
          : IdentityStatus.unverified);
  UserProfile copy() => UserProfile(
      id: id,
      phoneVerified: phoneVerified,
      available: available,
      name: name,
      specialty: specialty,
      activity: activity,
      city: city,
      coverage: coverage,
      bio: bio,
      experience: experience,
      availability: availability,
      avatar: avatar,
      coverPhoto: coverPhoto,
      complete: complete,
      skills: skills,
      photos: photos);
}
