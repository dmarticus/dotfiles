### Import Organization

- Imports at top of file - never inside functions or methods
- Group: node builtins → external packages → internal modules (blank line between)
- Use named exports (`export const DashboardMenu = () => ...`), avoid `default` exports
- For type-only imports:

```typescript
import type { User } from "./models";
// or
import { type User, createUser } from "./models";
```

### Type Safety

- Write all new code with TypeScript and proper typing
- Enable `strict: true` in tsconfig - never disable it
- Avoid `any` - use `unknown` and narrow with type guards
- Use `as const` for literal types, avoid type assertions (`as`)
- Prefer interfaces for object shapes, types for unions/intersections
- Use discriminated unions over optional fields for state:

```typescript
// Good - impossible states are unrepresentable
type Result<T> = { ok: true; value: T } | { ok: false; error: Error };

// Bad - allows invalid combinations
type Result<T> = { ok: boolean; value?: T; error?: Error };
```

### State Management: Kea vs React

**If Kea is used in the repo (e.g., PostHog), always use Kea over React state:**

- Don't use `useState` or `useEffect` to store local state - it's false convenience
- Write your frontend data handling code first, and write it in a Kea `logic`
- Think data first: get your mental model of the data flowing through the app right
- Derive state via selectors, update the source via cascading actions
- Use `subscriptions` and `propsChanged` sparingly - high chance of messy data flows

**Exception**: Library components in `lib/` folder (rendered hundreds of times) can use React state due to initialization cost. Still use a logic for complicated `lib/` components.

**If Kea is NOT used in the repo**, React hooks are fine:

- Use `useState` with explicit types for complex state
- Memoize callbacks with `useCallback`, computed values with `useMemo`

### Scenes & Tabs (Kea apps)

- App is built of _tabs that contain scenes_, managed through `sceneLogic`
- A scene is the smallest unit for routing and code splitting (usually split by resource type and function)
- Each scene exports a `SceneExport` object containing the scene's root `logic` and `component`
- Scene logic is auto-mounted on tab and receives `tabId: string` prop - key your logic with this
- Add `tabAwareScene()` to your scene's logic to catch bugs when mounting without `tabId`
- Use `tabAwareUrlToAction` and `tabAwareActionToUrl` instead of `urlToAction`/`actionToUrl`
- Only use URL actions in the scene's logic, not in deeper logics
- When a scene becomes inactive, it persists in background but React-mounted logics unmount
- Use `useAttachedLogic(childLogic(props), mySceneLogic({ tabId }))` to persist logics through React remounts
- Control tab display via `breadcrumbs` selector - last breadcrumb sets title/icon, previous sets back button

### Naming Conventions

- Follow environment conventions: `camelCase` in JS/TS, `snake_case` in Python
- Use clear, functional names (`searchResults` vs `data`)
- Logics are camelCase: `dashboardLogic`
- React components are PascalCase: `DashboardMenu`
- Props end with `Props` in PascalCase: `DashboardLogicProps`, `DashboardMenuProps`
- File names match main export: `DashboardMenu.tsx`, `dashboardLogic.ts`, `Dashboard.scss`
- Avoid generic names: no `index.ts`, `styles.css`

### Null Handling

- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Prefer `undefined` over `null` (TypeScript's convention)
- Use `Map.get()` with explicit undefined checks, not `||` (falsy trap)
- For arrays that might be empty, check `.length` before accessing

### Async Code

- Always `await` promises or return them - never fire and forget
- Use `Promise.all()` for concurrent operations, not sequential `await`
- Handle promise rejections - unhandled rejections crash Node
- Use `AbortController` for cancellable operations

```typescript
// Good - concurrent
const [users, posts] = await Promise.all([getUsers(), getPosts()]);

// Bad - sequential when it doesn't need to be
const users = await getUsers();
const posts = await getPosts();
```

### Error Handling

- Catch specific errors when possible, not bare `catch`
- Use `instanceof` to narrow error types
- In catch blocks, error is `unknown` - check before accessing `.message`
- For API routes, return typed error responses, don't throw

### CSS & Styling

- Use Tailwind CSS wherever possible
- Replace custom SCSS with Tailwind when you see opportunities
- When SCSS is needed:
  - Import `MyComponent.scss` inside `MyComponent.tsx`
  - Namespace all rules under globally unique class matching component: `.DashboardMenu { ... }`
  - Use BEM for elements that break out of DOM (e.g., modals): `.DashboardMenu__modal`

### Testing

- Write logic tests for all Kea logic files
- Write React Testing Library tests for interactive `lib/` components
- Add presentational elements and scenes to Storybook
- Prefer concrete assertions over length checks:

```typescript
// Good - shows what's wrong on failure
assert(response.json().results).toEqual(["x", "y"]);

// Bad - doesn't tell you what the actual values were
assert(response.json().results.length).toBe(2);
```

### Type Guards & Narrowing

- Write type guards for runtime validation of external data:

```typescript
function isUser(value: unknown): value is User {
  return (
    typeof value === "object" &&
    value !== null &&
    "id" in value &&
    typeof (value as User).id === "string"
  );
}
```

- Use `satisfies` to validate types while preserving inference:

```typescript
const config = {
  port: 3000,
  host: "localhost",
} satisfies ServerConfig;
```

### Package Manager

- Use `pnpm` - it's faster and stricter about dependencies
- Check `package.json` for existing deps before adding new ones
- Use exact versions in production apps (`"lodash": "4.17.21"`)

### Quality Checklist

Before committing TypeScript code:

1. `pnpm typecheck` (or `tsc --noEmit`)
2. `pnpm lint` (ESLint with `@typescript-eslint`)
3. `pnpm test`
4. Check for `any` types - each one needs justification
