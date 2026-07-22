(function() {
  var searchInput = document.getElementById('search-input');
  var searchResults = document.getElementById('search-results');
  var idx, pages;

  if (!searchInput) return;

  fetch(window.searchBaseUrl + '/search.json')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      pages = data;
      idx = lunr(function() {
        this.ref('url');
        this.field('title', { boost: 10 });
        this.field('content');
        data.forEach(function(p) { this.add(p); }, this);
      });
    });

  function getSnippet(content, query) {
    if (!content) return '';
    var words = query.trim().split(/\s+/);
    var lowerContent = content.toLowerCase();
    var bestIdx = -1;
    for (var i = 0; i < words.length; i++) {
      var pos = lowerContent.indexOf(words[i].toLowerCase());
      if (pos !== -1) { bestIdx = pos; break; }
    }
    if (bestIdx === -1) return content.substring(0, 140) + '...';
    var start = Math.max(0, bestIdx - 60);
    var end = Math.min(content.length, bestIdx + 160);
    var snippet = (start > 0 ? '...' : '') + content.substring(start, end) + (end < content.length ? '...' : '');
    words.forEach(function(word) {
      if (!word) return;
      var re = new RegExp('(' + word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
      snippet = snippet.replace(re, '<mark>$1</mark>');
    });
    return snippet;
  }

  function runSearch(query) {
    var results = [];
    var attempts = [
      query,                    // exact
      query + '*',              // wildcard suffix
      query + '~1',             // fuzzy distance 1
      query + '~2'              // fuzzy distance 2
    ];
    for (var i = 0; i < attempts.length; i++) {
      try {
        results = idx.search(attempts[i]);
        if (results.length > 0) break;
      } catch(e) { /* invalid query, try next */ }
    }
    return results;
  }

  function renderResults(query) {
    if (!idx || query.trim().length < 2) {
      searchResults.style.display = 'none';
      return;
    }

    var results = runSearch(query.trim());

    if (results.length === 0) {
      searchResults.innerHTML = '<div class="search-no-results">No results for "<strong>' + query + '</strong>"</div>';
      searchResults.style.display = 'block';
      return;
    }

    var html = '';
    results.slice(0, 8).forEach(function(r) {
      var page = pages.find(function(p) { return p.url === r.ref; });
      if (!page) return;
      var resultUrl = page.url + (page.url.indexOf('?') >= 0 ? '&' : '?') + 'q=' + encodeURIComponent(query);
      html += '<a class="search-result-item" href="' + resultUrl + '">' +
        '<div class="search-result-title">' + page.title + '</div>' +
        '<div class="search-result-snippet">' + getSnippet(page.content, query) + '</div>' +
        '</a>';
    });
    searchResults.innerHTML = html;
    searchResults.style.display = 'block';
  }

  searchInput.addEventListener('input', function() {
    renderResults(this.value);
  });

  searchInput.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeSearch();
    if (e.key === 'Enter') {
      var first = searchResults.querySelector('.search-result-item');
      if (first) {
        var url = first.getAttribute('href');
        var q = searchInput.value.trim();
        if (q) url += (url.indexOf('?') >= 0 ? '&' : '?') + 'q=' + encodeURIComponent(q);
        window.location.href = url;
      }
    }
  });

  document.addEventListener('click', function(e) {
    if (!searchInput.closest('.search-wrapper').contains(e.target)) {
      closeSearch();
    }
  });

  function closeSearch() {
    searchResults.style.display = 'none';
    searchInput.value = '';
  }
})();
