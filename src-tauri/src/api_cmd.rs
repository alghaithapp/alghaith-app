use tauri::ipc::Response;

#[tauri::command]
pub async fn api_request(
    url: String,
    method: String,
    headers: std::collections::HashMap<String, String>,
    body: Option<String>,
) -> Result<Response, String> {
    let client = reqwest::Client::builder()
        .danger_accept_invalid_certs(false)
        .build()
        .map_err(|e| e.to_string())?;

    let mut req = match method.to_uppercase().as_str() {
        "GET" => client.get(&url),
        "POST" => client.post(&url),
        "PUT" => client.put(&url),
        "DELETE" => client.delete(&url),
        _ => return Err("Invalid method".into()),
    };

    for (k, v) in &headers {
        req = req.header(k.as_str(), v.as_str());
    }

    if let Some(b) = body {
        req = req.body(b);
    }

    let res = req.send().await.map_err(|e| e.to_string())?;
    let status = res.status().as_u16();
    let body_bytes = res.bytes().await.map_err(|e| e.to_string())?;
    let mut vec = body_bytes.to_vec();

    // Prepend status as JSON header line
    let mut result = format!("{status}\n").into_bytes();
    result.append(&mut vec);

    Ok(Response::new(result))
}
