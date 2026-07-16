# Inspecting Element Attributes

> Modified upstream material: adapted from [`@playwright/cli`](https://github.com/microsoft/playwright-cli) and changed by playwright-cli-human contributors. See [NOTICE](../NOTICE) and [LICENSE](../LICENSE).

When the snapshot doesn't show an element's `id`, `class`, `data-*` attributes, or other DOM properties, use `eval` to inspect them.

## Examples

```bash
playwright-cli snapshot
# snapshot shows a button as e7 but doesn't reveal its id or data attributes

# get the element's id
playwright-cli eval "el => el.id" e7

# get all CSS classes
playwright-cli eval "el => el.className" e7

# get a specific attribute
playwright-cli eval "el => el.getAttribute('data-testid')" e7
playwright-cli eval "el => el.getAttribute('aria-label')" e7

# get a computed style property
playwright-cli eval "el => getComputedStyle(el).display" e7
```
