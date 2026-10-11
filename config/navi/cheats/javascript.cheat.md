```sh
% JavaScript/TypeScript

# JavaScript : measure fetch time
const startTime = Number(new Date());
const url = '<url>';
await fetch(url);
console.log(Number(new Date()) - startTime);

# JavaScript : sleep
await new Promise(resolve => setTimeout(resolve, 1000));

# DOM : query selector [ex:document.querySelector('div[data-props]').getAttribute('data-props')]
document.querySelector('<tag>[<attr>]').getAttribute('<attr>')
```

$ xxx: echo xxx
;$
