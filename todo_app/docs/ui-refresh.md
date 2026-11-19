# Refonte visuelle — thème violet

**Périmètre** : présentation uniquement. Aucun bloc, cas d'usage, repository, enregistrement DI,
ni garde de route n'a été modifié. Les 25 tests unitaires et de widget passent ; une seule
assertion a été reformulée, parce que le compteur a quitté le titre pour devenir une pastille
(voir § 7).

---

## 1. Fichiers

| Fichier | Nature | Rôle |
|---|---|---|
| `lib/core/theme/app_theme.dart` | nouveau | palette, typographie et styles de composants (clair + sombre) |
| `lib/core/widgets/app_logo.dart` | nouveau | la marque (carré violet arrondi + glyphe) |
| `lib/core/widgets/splash_screen.dart` | nouveau | écran d'attente pendant `AuthStarted` |
| `lib/features/auth/presentation/widgets/auth_header.dart` | nouveau | en-tête dégradé partagé par connexion / inscription |
| `lib/app.dart` | modifié | `theme` + `darkTheme` + `ThemeMode.light`, titre « Secure Todo » |
| `lib/core/router/app_router.dart` | modifié | le `builder` de `/splash` utilise `SplashScreen` (une ligne) |
| `login_page.dart`, `register_page.dart` | modifiés | mise en page + bouton afficher/masquer le mot de passe |
| `todos_page.dart` | modifié | app bar (logo, pastille), résumé de progression, filtres, états vide/erreur, FAB étendu |
| `todo_tile.dart` | modifié | carte arrondie, case circulaire, fond de glissement arrondi |
| `add_todo_sheet.dart` | modifié | poignée de glissement, titre « New todo » |

Les callbacks, validateurs et événements de bloc sont inchangés. Les textes assertés par les
tests le restent aussi (`'My todos'`, `'n left'`, `Retry`, `tooltip: 'Sign out'`, `'Sign in'`…),
à une exception près, documentée en § 7.

---

## 2. La palette

Une seule couleur source :

```dart
static const Color seed = Color(0xFF7C3AED); // violet
```

`ColorScheme.fromSeed` en dérive tous les rôles Material 3 (`primary`, `primaryContainer`,
`surfaceContainerLow`, `outlineVariant`, `inverseSurface`…). Conséquences :

- les pages n'écrivent **aucune** couleur en dur : elles demandent `Theme.of(context).colorScheme`,
  donc le mode sombre ne demande aucune branche `if (isDark)` ;
- changer la marque plus tard = changer une ligne ;
- le contraste texte/fond est garanti par Material, pas à l'œil.

L'application démarre en **thème clair** (`themeMode: ThemeMode.light`). Le schéma sombre est
construit et prêt, mais n'est pas imposé par le réglage du téléphone : il suffit de passer à
`ThemeMode.system` dans `app.dart` pour le réactiver.

L'en-tête d'authentification n'est plus un bloc violet saturé : c'est un lavis
`primaryContainer` qui se fond dans le fond de page.

```dart
colors: [
  scheme.primaryContainer.withValues(alpha: 0.75),
  scheme.surface,
]
```

La marque reste lisible (pastille `primary` + mot-clé violet) sans assombrir le haut de l'écran.

---

## 3. Styles mis dans le thème (et non dans les pages)

| Composant | Réglage |
|---|---|
| Cartes | élévation 0, bordure `outlineVariant` à 70 %, rayon 18 |
| Champs | remplis, sans bordure, bordure violette 1,6 px au focus |
| Boutons remplis | hauteur min. 52, rayon 16, libellé gras |
| `SegmentedButton` | segment sélectionné rempli en violet, rayon 14 |
| `Checkbox` | circulaire, rempli en violet une fois coché |
| FAB | violet, rayon 18, libellé gras |
| `SnackBar` | flottante, rayon 14, `inverseSurface` |
| `BottomSheet` | rayon 28 en haut, poignée visible, sans teinte de surface |

Ainsi `TodoTile` et `TodosPage` restent courts : la cohérence vient du thème, pas de la répétition.

---

## 4. Améliorations d'usage (au-delà de la couleur)

1. **Afficher / masquer le mot de passe** — état purement local (`bool _obscure`), aucun impact sur
   l'envoi du formulaire.
2. **Barre de filtres pleine largeur** avec icônes : trois zones tactiles égales, plus faciles à
   viser au pouce que trois pastilles collées au centre.
3. **États vides contextualisés** : « Nothing here yet », « All done », « Nothing completed ».
   Avant, filtrer sur *Done* avec zéro tâche terminée affichait « Nothing here. Tap +… », ce qui
   était faux (il y avait des tâches, simplement aucune terminée).
4. **Pull-to-refresh toujours possible** : `AlwaysScrollableScrollPhysics` sur les deux listes.
   Sans cela, avec une seule tâche, la liste ne défile pas et le geste de rafraîchissement ne
   déclenche rien.
5. **FAB étendu « New todo »** : l'action principale est nommée, plus seulement une icône `+`.
6. **Erreur de chargement** : icône, message, bouton *Retry* (la `SnackBar` reste pour les erreurs
   d'action, pas pour l'écran vide).
7. **Liste avec espacement** (`ListView.separated`, 10 px) et marge basse de 96 px pour que la
   dernière tâche ne passe jamais sous le FAB.
8. **Indicateur de chargement lisible** : dans un bouton rempli violet, le spinner utilisait
   `primary` — donc violet sur violet. Il prend maintenant `onPrimary`.

---

## 5. Deuxième passe (design)

La première version était correcte mais sobre. La seconde ajoute de la hiérarchie visuelle,
toujours sans toucher à la logique :

| Ajout | Effet |
|---|---|
| Résumé de progression (`n of m done` + barre animée) | on voit d'un coup d'œil où on en est ; masqué quand la liste est vide |
| Pastille `n left` dans l'app bar | le compteur reste visible en permanence, sans alourdir le titre |
| `AnimatedSwitcher` autour de la liste | fondu entre chargement / vide / liste, plus de « saut » |
| Disques décoratifs dans l'en-tête d'auth | profondeur visuelle, sans image ni flou |
| Entrée animée du splash (fondu + montée, 550 ms) | apparition propre, aucune boucle |
| États vides dans un disque dégradé | l'écran vide ressemble à un état voulu, pas à un bug |

Toutes ces animations sont pilotées par des widgets (`TweenAnimationBuilder`,
`AnimatedSwitcher`) et non par des contrôleurs : rien à `dispose`, rien à oublier.

---

## 6. Vérifications

```
$ flutter analyze
No issues found!

$ flutter test
00:05 +25: All tests passed!        (les 16 tests d'intégration restent ignorés par défaut)

$ flutter build web
✓ Built build/web
```

Testé aussi sur un **TECNO KN4** (Android 16) en USB, via `adb reverse tcp:3000 tcp:3000` :
l'app atteint l'API sur `http://localhost:3000/api/v1` sans ouvrir le port sur le Wi-Fi.

---

## 7. La seule modification de test

Le titre était `'My todos (1 left)'`. Avec la pastille, il devient deux textes distincts :
`'My todos'` et `'1 left'`. Trois assertions de `todos_page_test.dart` ont donc été réécrites,
mécaniquement :

```dart
expect(find.text('My todos'), findsOneWidget);
expect(find.text('1 left'), findsOneWidget);
expect(find.text('1 of 2 done'), findsOneWidget);
```

Aucune assertion de comportement n'a changé : la `Checkbox` est toujours cliquée, la tuile
toujours glissée, le rollback et la `SnackBar` toujours vérifiés.

---

## 8. Icône du lanceur (marque)

L'icône par défaut de Flutter est remplacée par la marque de l'application. Le SVG n'est **pas**
utilisé directement (ni Android ni iOS ne le lisent) : il sert de source, rasterisée à toutes les
tailles par `tool/generate_icons.sh` (Inkscape).

| Source | Usage |
|---|---|
| `assets/branding/app_icon.svg` | carré violet arrondi — Android legacy, icônes web `any`, favicon |
| `assets/branding/app_icon_foreground.svg` | le check seul, transparent — avant-plan de l'icône adaptative |
| `assets/branding/app_icon_maskable.svg` | carré plein bord — iOS (le système arrondit) et web `maskable` |

Produits : 5 densités Android (`ic_launcher`, `ic_launcher_foreground`, `ic_launcher_monochrome`),
15 tailles iOS, `favicon.png` et les 4 icônes web.

Deux détails qui font échouer les builds si on les oublie :

1. **iOS refuse le canal alpha.** Les PNG sont aplatis (`-alpha remove -alpha off`) ; un 1024×1024
   RGBA, même entièrement opaque, est rejeté par l'App Store.
2. **`monochrome` n'existe qu'à partir de l'API 33.** Il est déclaré dans
   `mipmap-anydpi-v33/ic_launcher.xml` ; la variante `-v26` ne contient que fond + avant-plan,
   sinon les appareils Android 8–12 lisent un attribut inconnu.

Le label du lanceur passe aussi à « Secure Todo » (`android:label`, `CFBundleDisplayName`,
`manifest.json`), et la couleur de thème web à `#7C3AED`.

Pour mettre votre propre logo : remplacez les SVG (mêmes dimensions de canevas), relancez
`./tool/generate_icons.sh`, réinstallez. Aucun autre fichier ne référence le dessin.

---

## 9. Piste suivante

Le mode sombre existe mais n'est pas exposé. Pour laisser l'utilisateur choisir (et s'en souvenir),
il suffit d'ajouter un `ThemeCubit` + `hydrated_bloc` et de passer `themeMode` à
`context.select((ThemeCubit c) => c.state)` dans `app.dart`. `app_theme.dart` n'aurait pas à changer.
