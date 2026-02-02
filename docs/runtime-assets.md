# Smart Farmer Runtime Asset Registry

## Asset Categories

- **Icons**: All tab, action, and navigation icons (e.g., home, scan, notification)
- **Backgrounds**: Page and screen backgrounds (e.g., splash, scan, dashboard)
- **Overlays**: UI overlays (e.g., camera overlay)
- **Logo**: App logo and app icon

## How to Add a New Runtime Asset

1. **Add the asset file** to the correct folder under `smart_farmer/assets/`.
   - Use lowercase, snake_case, and Android-safe names.
2. **Update the registry**: Add an explicit entry in `utils/assetsRegistry.ts` under the correct category.
3. **Test**: Run the asset registry tests in `smart_farmer.tests/` to ensure the asset resolves correctly.

## Rules
- **Never import images via raw string paths.**
- **Always use the asset registry** for all runtime asset imports.
- **Do not rename or move assets without updating the registry and tests.**
- **Validation**: The registry and validation utility catch missing or broken asset paths early in development.

## Example Usage
```ts
import { Icons, Backgrounds } from '../utils/assetsRegistry';
<Image source={Icons.home} />
```

## Validation
- The validation utility (`utils/validateAssets.ts`) can be run at app startup (dev only) or via tests.
- It will throw an error if any asset is missing or broken.
