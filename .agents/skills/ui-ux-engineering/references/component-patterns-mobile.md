# Patterns d'Ergonomie Mobile (React Native, Flutter, Swift, Kotlin) — Référence

Ce document détaille les patterns pour concevoir des applications mobiles réactives, fluides et respectueuses des standards natifs (iOS Human Interface Guidelines & Android Material 3).

---

## 📋 Table des matières

1. [La "Thumb Zone" (Zone du Pouce) & Cibles Tactiles](#1-la-thumb-zone-zone-du-pouce--cibles-tactiles)
2. [Gestion Obligatoire de la Safe Area (Encoche & Barre d'accueil)](#2-gestion-obligatoire-de-la-safe-area)
3. [Bottom Sheets & Tiroirs Contextuels Tactiles](#3-bottom-sheets--tiroirs-contextuels-tactiles)
4. [Retours Haptiques (Haptic Feedback)](#4-retours-haptiques-haptic-feedback)
5. [Pull-to-Refresh & Listes Virtualisées](#5-pull-to-refresh--listes-virtualisées)

---

## 1. La "Thumb Zone" (Zone du Pouce) & Cibles Tactiles

Sur les téléphones modernes de 6,5+ pouces, le haut de l'écran est inaccessible à une main sans repositionner la prise :
* **Zone Basse (Facile) :** Placer la barre d'onglets principale, les boutons d'action flottants (FAB), les boutons de confirmation et les filtres.
* **Zone Haute (Difficile) :** Réserver aux informations de statut passives (titres, métadonnées, état de synchronisation).
* **Cible Minimale :** Toute zone tactile doit mesurer au minimum **48x48 dp** sur Android et **44x44 pt** sur iOS. Si une icône fait 20px, son padding parent doit compléter à 48px (`minHeight: 48, minWidth: 48`).

---

## 2. Gestion Obligatoire de la Safe Area

Ne jamais laisser du texte ou des boutons passer sous la Dynamic Island / encoche supérieure ou sous la barre de navigation gesture inférieure.

### React Native
```tsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';

export function ScreenContainer({ children }: { children: React.ReactNode }) {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.container, { paddingTop: insets.top, paddingBottom: insets.bottom }]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#09090B', // Fond sombre sobre
  },
});
```

### Flutter
```dart
import 'package:flutter/material.dart';

class SafeScreenWrapper extends StatelessWidget {
  final Widget child;

  const SafeScreenWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: child,
        ),
      ),
    );
  }
}
```

---

## 3. Bottom Sheets & Tiroirs Contextuels Tactiles

Pour les actions secondaires, la saisie de filtres ou la confirmation d'une action, préférer une **Bottom Sheet** interactive plutôt qu'une boîte de dialogue centrale bloquante.

### React Native (avec `@gorhom/bottom-sheet`)
```tsx
import React, { useRef, useMemo } from 'react';
import BottomSheet, { BottomSheetView } from '@gorhom/bottom-sheet';
import { Text, StyleSheet, Pressable } from 'react-native';

export function SecurityActionSheet({ isOpen, onClose }: any) {
  const bottomSheetRef = useRef<BottomSheet>(null);
  const snapPoints = useMemo(() => ['35%', '60%'], []);

  return (
    <BottomSheet
      ref={bottomSheetRef}
      snapPoints={snapPoints}
      enablePanDownToClose
      backgroundStyle={styles.sheetBackground}
      handleIndicatorStyle={styles.indicator}
    >
      <BottomSheetView style={styles.content}>
        <Text style={styles.title}>Confirmer l'opération de sécurité</Text>
        <Text style={styles.subtitle}>Cette action révoquera les accès de tous les terminaux actifs.</Text>

        <Pressable style={styles.destructiveButton} onPress={onClose}>
          <Text style={styles.buttonText}>Révoquer immédiatement</Text>
        </Pressable>
      </BottomSheetView>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({
  sheetBackground: { backgroundColor: '#18181B' },
  indicator: { backgroundColor: '#52525B', width: 40 },
  content: { padding: 20 },
  title: { fontSize: 16, fontWeight: '600', color: '#FAFAFA' },
  subtitle: { fontSize: 13, color: '#A1A1AA', marginTop: 8, marginBottom: 20 },
  destructiveButton: {
    height: 48,
    borderRadius: 8,
    backgroundColor: '#E11D48',
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonText: { color: '#FFFFFF', fontWeight: '600', fontSize: 14 },
});
```

---

## 4. Retours Haptiques (Haptic Feedback)

Sur mobile, une interaction réussie (ex: bascule d'un switch, confirmation biométrique) doit procurer une sensation tactile physique immédiate.

```javascript
// React Native avec react-native-haptic-feedback
import ReactNativeHapticFeedback from "react-native-haptic-feedback";

const hapticOptions = {
  enableVibrateFallback: true,
  ignoreAndroidSystemSettings: false,
};

// Lors d'un toggle réussi
export const triggerSelectionHaptic = () => {
  ReactNativeHapticFeedback.trigger("selection", hapticOptions);
};

// Lors d'une validation critique / succès
export const triggerSuccessHaptic = () => {
  ReactNativeHapticFeedback.trigger("notificationSuccess", hapticOptions);
};

// Lors d'une erreur ou action destructive
export const triggerWarningHaptic = () => {
  ReactNativeHapticFeedback.trigger("notificationWarning", hapticOptions);
};
```

---

## 5. Pull-to-Refresh & Listes Virtualisées

Pour préserver 60/120 FPS sur les appareils d'entrée de gamme :
* Utiliser `FlashList` (Shopify) ou `FlatList` avec `windowSize={5}` et `getItemLayout` quand la hauteur est fixe.
* Ne jamais charger 500 éléments dans une `ScrollView` simple sous peine de saturation mémoire.
