part of 'main.dart';

extension WorkPersistence on _AppShellState {
  Map<String, Object?> profileJson(UserProfile p) => {
        'id': p.id,
        'name': p.name,
        'specialty': p.specialty,
        'activity': p.activity.name,
        'city': p.city,
        'bio': p.bio,
        'experience': p.experience,
        'availability': p.availability,
        'complete': p.complete,
        'phoneVerified': p.phoneVerified,
        'available': p.available,
        'skills': p.skills.toList(),
        'avatar': p.avatar == null ? null : base64Encode(p.avatar!),
        'photos': p.photos
            .map((x) => {
                  'asset': x.asset,
                  'bytes': x.bytes == null ? null : base64Encode(x.bytes!)
                })
            .toList(),
        'coverage': p.coverage == null
            ? null
            : {
                'province': p.coverage!.province,
                'city': p.coverage!.city,
                'districts': p.coverage!.districts.toList(),
                'surroundings': p.coverage!.surroundings
              },
      };
  UserProfile profileFrom(Json j) {
    final area = j['coverage'];
    return UserProfile(
        id: j['id'],
        name: j['name'],
        specialty: j['specialty'],
        activity: ActivityType.values.byName(j['activity']),
        city: j['city'],
        bio: j['bio'],
        experience: j['experience'],
        availability: j['availability'],
        complete: j['complete'],
        phoneVerified: j['phoneVerified'],
        available: j['available'],
        skills: List<String>.from(j['skills']),
        avatar: j['avatar'] == null ? null : base64Decode(j['avatar']),
        coverage: area == null
            ? null
            : AreaFilter(
                province: area['province'],
                city: area['city'],
                districts: Set<String>.from(area['districts']),
                surroundings: area['surroundings']),
        photos: (j['photos'] as List).map((p) => p['asset'] != null
            ? ProfilePhoto.asset(p['asset'])
            : ProfilePhoto.bytes(base64Decode(p['bytes']))));
  }

  Map<String, Object?> revisionJson(ContractRevision v) => {
        'number': v.number,
        'title': v.title,
        'template': v.template,
        'parentId': v.parentId,
        'values': v.values,
        'photos': v.photos.map(base64Encode).toList(),
        'createdAt': v.createdAt.toIso8601String()
      };
  ContractRevision revisionFrom(Json j) => ContractRevision(
      number: j['number'],
      title: j['title'],
      template: j['template'],
      parentId: j['parentId'],
      values: Map<String, String>.from(j['values']),
      photos: (j['photos'] as List).map((p) => base64Decode(p)).toList(),
      createdAt: DateTime.parse(j['createdAt']));
  Map<String, Object?> contractJson(ContractDraft d) => {
        'id': d.id,
        'title': d.title,
        'template': d.template,
        'parentId': d.parentId,
        'values': d.values,
        'photos': d.photos.map(base64Encode).toList(),
        'status': d.status,
        'threadId': d.threadId,
        'revisions': d.revisions.map(revisionJson).toList()
      };
  ContractDraft contractFrom(Json j) =>
      ContractDraft(j['title'], Map<String, String>.from(j['values']),
          template: j['template'], parentId: j['parentId'], restoredId: j['id'])
        ..status = j['status']
        ..threadId = j['threadId']
        ..photos.addAll((j['photos'] as List).map((p) => base64Decode(p)))
        ..revisions.addAll((j['revisions'] as List)
            .map((v) => revisionFrom(Map<String, dynamic>.from(v))));
  Map<String, Object?> workSnapshot() => {
        'version': 1,
        'structureVersion': 2,
        'work': workStore.toJson(),
        'profiles': profileRepository.profiles.map(profileJson).toList(),
        'profileViews': {
          for (final e in profileRepository.profileViews.entries)
            e.key: {
              for (final v in e.value.entries) v.key: v.value.toIso8601String()
            }
        },
        'accounts': {
          for (final e in accountSpaces.entries)
            e.key: {
              'profileId': e.value.profile.id,
              'savedIds': e.value.savedIds.toList(),
              'likedIds': e.value.likedIds.toList(),
              'savedPeople': e.value.savedPeople.values
                  .map(findProfile)
                  .whereType<UserProfile>()
                  .map((p) => p.id)
                  .toList(),
              'contracts': e.value.drafts.map(contractJson).toList(),
              'reviews': e.value.workReviews
                  .map((r) => {
                        'peer': r.peer,
                        'contextId': r.contextId,
                        'subject': r.subject,
                        'outcome': r.outcome,
                        'text': r.text,
                        'punctuality': r.punctuality,
                        'quality': r.quality,
                        'subjectProfileId': r.subjectProfileId,
                        'authorProfileId': r.authorProfileId,
                        'reply': r.reply,
                        'createdAt': r.createdAt.toIso8601String(),
                      })
                  .toList(),
            }
        },
        'teams': profileRepository.links
            .map((l) => {
                  'id': l.id,
                  'ownerId': l.ownerId,
                  'memberId': l.memberId,
                  'status': l.status.name
                })
            .toList(),
        'notices': profileRepository.notices
            .map((n) => {'profileId': n.profileId, 'text': n.text})
            .toList(),
        'rules': profileRepository.acceptances
            .map((r) => {'profileId': r.profileId, 'version': r.version})
            .toList(),
        'reports': reports
            .map((r) => {
                  'authorId': r.authorId,
                  'targetId': r.targetId,
                  'reason': r.reason,
                  'note': r.note
                })
            .toList(),
      };
  Future<void> loadWork() async {
    try {
      final data = await demoStore.load();
      if (!mounted) {
        await demoStore.close();
        return;
      }
      if (data != null) {
        // Decode before replacing the live demo. An incompatible snapshot is never overwritten.
        final j = Map<String, dynamic>.from(data);
        if (j['version'] != 1)
          throw const FormatException('نسخه داده پشتیبانی نمی‌شود.');
        final recovered = DemoWorkRepository()
          ..restore(Map<String, dynamic>.from(j['work']));
        final profiles = (j['profiles'] as List)
            .map((p) => profileFrom(Map<String, dynamic>.from(p)))
            .toList();
        if (j['structureVersion'] != 2) {
          migrateStructureDemo(recovered, profiles, workStore.services.values);
          for (final n in recovered.needs.values) {
            if (n.skills.isEmpty && workStore.needs.containsKey(n.id))
              n.skills = List.from(workStore.needs[n.id]!.skills);
          }
        }
        final accounts = <String, AccountWorkspace>{};
        for (final e in Map<String, dynamic>.from(j['accounts']).entries) {
          final x = Map<String, dynamic>.from(e.value), w = AccountWorkspace();
          w.profile = profiles.firstWhere((p) => p.id == x['profileId']);
          w.savedIds.addAll(List<String>.from(x['savedIds']));
          w.likedIds.addAll(List<String>.from(x['likedIds']));
          for (final id in x['savedPeople']) {
            final p = profiles.where((p) => p.id == id).firstOrNull;
            if (p != null) w.savedPeople[id] = profileCard(p);
          }
          w.drafts.addAll((x['contracts'] as List)
              .map((d) => contractFrom(Map<String, dynamic>.from(d))));
          if (j['structureVersion'] != 2) {
            for (final d in w.drafts) {
              if (d.values['موضوع و محل'] ==
                  'نصب و اجاره داربست — کرج، گوهردشت')
                d.values['موضوع و محل'] = 'نصب و اجاره داربست — مشهد، الهیه';
            }
          }
          for (final r in x['reviews'] ?? []) {
            w.workReviews.add(WorkReview(
                r['peer'],
                r['contextId'],
                r['subject'],
                r['outcome'],
                r['text'],
                r['punctuality'],
                r['quality'],
                subjectProfileId: r['subjectProfileId'],
                authorProfileId: r['authorProfileId'],
                at: DateTime.parse(r['createdAt']))
              ..reply = r['reply']);
          }
          accounts[e.key] = w;
        }
        workStore.restore(recovered.toJson());
        for (final p in profiles) {
          profileRepository.save(p);
        }
        profileRepository.profileViews.clear();
        for (final e
            in Map<String, dynamic>.from(j['profileViews'] ?? {}).entries) {
          profileRepository.profileViews[e.key] =
              Map<String, dynamic>.from(e.value)
                  .map((key, value) => MapEntry(key, DateTime.parse(value)));
        }
        accountSpaces.clear();
        accountSpaces.addAll(accounts);
        if (activePhone != null)
          workspace = accountSpaces[activePhone] ?? AccountWorkspace();
        profileRepository.links.clear();
        for (final l in j['teams']) {
          profileRepository.links.add(
              TeamLink(l['id'], l['ownerId'], l['memberId'])
                ..status = TeamLinkStatus.values.byName(l['status']));
        }
        profileRepository.notices.clear();
        for (final n in j['notices']) {
          profileRepository.notices
              .add(AccountNotice(n['profileId'], n['text']));
        }
        profileRepository.acceptances.clear();
        for (final r in j['rules']) {
          profileRepository.acceptances
              .add(RulesAcceptance(r['profileId'], r['version']));
        }
        reports.clear();
        for (final r in j['reports']) {
          reports.add(
              DemoReport(r['authorId'], r['targetId'], r['reason'], r['note']));
        }
      }
      storageReady = true;
      final incoming = Uri.base.queryParameters['profile'];
      if (incoming != null) {
        final p = profileRepository.profile(incoming);
        page = p == null ? 'publicMissing' : 'pro';
        if (p != null) {
          selectedAd = profileCard(p);
          recordProfileView(p);
        }
      }
    } catch (_) {
      storageFailed = true;
      if (mounted)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            notice(
                'ذخیره محلی در دسترس نیست؛ تغییرات این اجرا موقت خواهند بود.');
        });
    }
    if (mounted) update(() => loadingDemo = false);
    if (storageReady) persistWork();
  }

  void persistWork() {
    if (!widget.persistDemo || !storageReady || loadingDemo) return;
    // Freeze now: queued writes must not observe later mutations.
    final snapshot =
        Map<String, Object?>.from(jsonDecode(jsonEncode(workSnapshot())));
    demoStore.save(snapshot).catchError((_) {
      if (mounted && !storageFailed) {
        storageFailed = true;
        notice(
            'ذخیره انجام نشد؛ تغییرات اخیر ممکن است با بستن برنامه از بین بروند.');
      }
    });
  }
}
