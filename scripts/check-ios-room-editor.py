#!/usr/bin/env python3
"""Run production wardrobe and room editor checks against frozen iOS release source."""
from pathlib import Path
import subprocess,sys
if len(sys.argv) != 2: raise SystemExit('Usage: check-ios-room-editor.py FROZEN_RELEASE_DIRECTORY')
release=Path(sys.argv[1]).resolve();root=release/'source/iOS'
base='Shared/Mascot/MascotMotion.swift Shared/Mascot/MascotFrames.swift Shared/Mascot/WardrobeArt.swift Shared/Mascot/HeritageArt.swift Shared/Mascot/HomeSceneLayout.swift Shared/Mascot/RoomArrangement.swift Shared/Mascot/RoomPlacement.swift Shared/Mascot/CompanionAccessory.swift Clockin/Celebrations/CelebrationRules.swift Shared/Core/Models.swift Shared/Core/WardrobeBackup.swift Shared/Mascot/Wardrobe.swift Shared/Mascot/WardrobePalette.swift Shared/Mascot/WardrobeCatalog.swift Clockin/Views/Goals/GoalProgress.swift Clockin/Views/Insights/InsightsSnapshot.swift Clockin/Views/Insights/InsightsBadges.swift Clockin/Views/Insights/BadgeTier.swift Clockin/Views/Insights/PurchaseBadges.swift Clockin/Views/Companion/WardrobeEarnings.swift'.split()
for suite in ['wardrobe', 'roomeditor']:
    args=['swiftc','-swift-version','6','-strict-concurrency=complete','-D','WIDGET_EXTENSION','-module-cache-path',str(release/'manual-module-cache')]+base+[f'Tests/manual/{suite}/main.swift','-o',str(release/f'check-{suite}')]
    log=release/f'{suite}.log'
    with log.open('w') as output:
        result=subprocess.run(args,cwd=root,stdout=output,stderr=subprocess.STDOUT)
        if result.returncode==0:result=subprocess.run([str(release/f'check-{suite}')],cwd=root,stdout=output,stderr=subprocess.STDOUT)
    print(suite,result.returncode,'\n'.join(log.read_text().splitlines()[-8:]),flush=True)
    if result.returncode:sys.exit(1)
