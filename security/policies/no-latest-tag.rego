# OPA Gatekeeper — blocks :latest image tags at Kubernetes admission.
# Applied at cluster level — no pod can deploy with :latest.
# SolarWinds attack vector: poisoned :latest tag = instant compromise.
# Immutable tags (sha-abc123f) = you know exactly what code is running.

package k8snolatestimage

violation[{"msg": msg}] {
  container := input.review.object.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf(
    "Container '%v' uses :latest tag. Use immutable tag e.g. sha-abc123f or v1.2.3",
    [container.name]
  )
}

violation[{"msg": msg}] {
  container := input.review.object.spec.containers[_]
  not contains(container.image, ":")
  msg := sprintf(
    "Container '%v' has no tag at all. Specify an immutable tag.",
    [container.name]
  )
}

# Also check initContainers
violation[{"msg": msg}] {
  container := input.review.object.spec.initContainers[_]
  endswith(container.image, ":latest")
  msg := sprintf(
    "InitContainer '%v' uses :latest tag.",
    [container.name]
  )
}