$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://localhost:8741/')
$listener.Start()
Write-Output "Serving on http://localhost:8741/"
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript'; '.svg'='image/svg+xml'; '.json'='application/json'; '.png'='image/png'; '.jpg'='image/jpeg'; '.css'='text/css' }
while ($true) {
  $ctx = $listener.GetContext()
  $path = [uri]::UnescapeDataString($ctx.Request.Url.LocalPath).TrimStart('/')
  if ($path -eq '') { $path = 'index.html' }
  $full = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath $path
  if (Test-Path $full -PathType Leaf) {
    $bytes = [IO.File]::ReadAllBytes($full)
    $ext = [IO.Path]::GetExtension($full).ToLower()
    if ($types.ContainsKey($ext)) { $ctx.Response.ContentType = $types[$ext] }
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else {
    $ctx.Response.StatusCode = 404
  }
  $ctx.Response.Close()
}
