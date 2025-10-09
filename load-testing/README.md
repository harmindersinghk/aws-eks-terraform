# Load Testing with Locust

This directory contains a comprehensive load testing solution for the Online Boutique microservices application using [Locust](https://locust.io/), a modern load testing framework written in Python.

## Overview

The load testing setup includes:
- **Realistic user simulation** for the Online Boutique e-commerce application
- **Distributed testing** with Locust master and worker pods
- **Kubernetes-native deployment** with proper resource management
- **GitHub Actions integration** for automated testing
- **Comprehensive reporting** with CSV and HTML outputs

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Locust Web    │    │  Locust Master   │    │ Online Boutique │
│   UI (8089)     │◄──►│    (1 pod)       │◄──►│   Frontend      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │ Locust Workers   │
                       │   (3 pods)       │
                       └──────────────────┘
```

## User Simulation

The load testing script simulates realistic user behavior:

### OnlineBoutiqueUser (Primary User Type)
- **Browse homepage** (most common action)
- **Browse products** by category
- **View product details**
- **Add items to cart**
- **Complete checkout process**
- **Change currency preferences**
- **Search for products**
- **View recommendations**

### AdminUser (Monitoring User)
- **Health checks** (`/health`, `/ready`)
- **Metrics monitoring** (`/metrics`)
- **System monitoring** tasks

### HighVolumeUser (Stress Testing)
- **Rapid browsing** patterns
- **High-frequency actions**
- Used for stress testing scenarios

## Quick Start

### Prerequisites

1. **EKS cluster** must be running
2. **Online Boutique application** must be deployed
3. **kubectl** configured to access your cluster
4. **AWS CLI** configured with appropriate permissions

### Deploy Locust

```bash
# Deploy Locust infrastructure
./scripts/deploy-locust.sh deploy

# Check deployment status
./scripts/deploy-locust.sh status

# View logs
./scripts/deploy-locust.sh logs
```

### Access Web UI

After deployment, you'll get the LoadBalancer URL:
```
Web UI URL: http://your-loadbalancer-url:8089
```

Or use port-forwarding:
```bash
kubectl port-forward service/locust-master 8089:8089 -n load-testing
# Then open http://localhost:8089
```

### Run Load Test

1. Open the Locust Web UI
2. Configure test parameters:
   - **Number of users**: Start with 50
   - **Spawn rate**: 2 users per second
   - **Host**: `http://frontend-external.app.svc.cluster.local`
3. Click "Start swarming"
4. Monitor real-time statistics

## GitHub Actions Integration

### Manual Load Test

Run load tests via GitHub Actions:

1. Go to **Actions** → **Run Load Test**
2. Configure parameters:
   - **Users**: Number of concurrent users (default: 50)
   - **Spawn Rate**: Users per second (default: 2)
   - **Duration**: Test duration (default: 10m)
   - **Test Type**: normal, stress, or spike
   - **Cleanup**: Auto-cleanup after test (default: true)

### Automated Testing

The workflow can be triggered:
- **Manually** via workflow_dispatch
- **On schedule** (add cron trigger)
- **After deployments** (add workflow dependency)

## Test Scenarios

### Normal Load Test
```yaml
users: 50
spawn_rate: 2
run_time: 10m
```
Simulates typical user traffic patterns.

### Stress Test
```yaml
users: 200
spawn_rate: 10
run_time: 15m
```
Tests system behavior under high load.

### Spike Test
```yaml
users: 500
spawn_rate: 50
run_time: 5m
```
Tests system response to sudden traffic spikes.

## Configuration

### Locust Configuration (`locust.conf`)
```ini
web-host = 0.0.0.0
web-port = 8089
users = 50
spawn-rate = 2
run-time = 10m
loglevel = INFO
csv = /tmp/results
html = /tmp/report.html
```

### Kubernetes Resources

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Master    | 250m        | 256Mi          | 500m      | 512Mi        |
| Worker    | 100m        | 128Mi          | 200m      | 256Mi        |

### Scaling Workers

To handle more load, scale the worker deployment:
```bash
kubectl scale deployment locust-worker --replicas=5 -n load-testing
```

## Monitoring and Results

### Real-time Monitoring
- **Web UI Dashboard**: Real-time statistics and graphs
- **Request statistics**: Response times, failure rates, RPS
- **Resource monitoring**: CPU, memory usage of pods

### Result Files
- **CSV files**: Detailed statistics and history
- **HTML report**: Comprehensive test report
- **Logs**: Detailed execution logs

### Key Metrics
- **Response Time**: Average, min, max response times
- **Throughput**: Requests per second (RPS)
- **Error Rate**: Percentage of failed requests
- **Concurrent Users**: Number of active users

## Troubleshooting

### Common Issues

**Locust workers not connecting to master:**
```bash
# Check worker logs
kubectl logs deployment/locust-worker -n load-testing

# Verify master service
kubectl get service locust-master-internal -n load-testing
```

**High error rates:**
- Check Online Boutique application health
- Verify resource limits aren't being exceeded
- Monitor cluster node resources

**LoadBalancer not getting external IP:**
```bash
# Use port-forward instead
kubectl port-forward service/locust-master 8089:8089 -n load-testing
```

### Debugging Commands

```bash
# Check all resources
kubectl get all -n load-testing

# Describe problematic pods
kubectl describe pod <pod-name> -n load-testing

# Check events
kubectl get events -n load-testing --sort-by='.lastTimestamp'

# View detailed logs
kubectl logs -f deployment/locust-master -n load-testing
```

## Cleanup

### Manual Cleanup
```bash
./scripts/deploy-locust.sh cleanup
```

### Verify Cleanup
```bash
kubectl get namespace load-testing
# Should return "NotFound"
```

## Best Practices

### Load Testing
1. **Start small**: Begin with low user counts and gradually increase
2. **Monitor resources**: Watch cluster and application metrics
3. **Test incrementally**: Test individual components before full system
4. **Use realistic data**: Simulate actual user behavior patterns

### Performance Tuning
1. **Scale workers**: Add more workers for higher load
2. **Adjust resources**: Increase CPU/memory limits if needed
3. **Monitor bottlenecks**: Identify limiting factors in the system
4. **Test different scenarios**: Vary user patterns and load types

### Security
1. **Network policies**: Restrict traffic between namespaces
2. **Resource limits**: Prevent resource exhaustion
3. **RBAC**: Use minimal required permissions
4. **Cleanup**: Always clean up test resources

## Integration with CI/CD

### Pre-deployment Testing
```yaml
# Add to your deployment workflow
- name: Run smoke test
  uses: ./.github/workflows/run_load_test.yml
  with:
    users: 10
    run_time: 2m
    test_type: normal
```

### Performance Regression Testing
```yaml
# Schedule regular performance tests
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM
```

## Advanced Configuration

### Custom Test Scenarios

Create custom locustfiles for specific scenarios:
```python
# custom_scenario.py
from locust import HttpUser, task, between

class CustomUser(HttpUser):
    wait_time = between(1, 3)
    
    @task
    def custom_behavior(self):
        # Your custom test logic
        pass
```

### Environment-specific Configuration

Use different configurations for different environments:
```bash
# Development
kubectl apply -f k8s-manifests/dev/

# Production
kubectl apply -f k8s-manifests/prod/
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Kubernetes events and logs
3. Consult the [Locust documentation](https://docs.locust.io/)
4. Check the GitHub repository issues

## Contributing

To improve the load testing setup:
1. Fork the repository
2. Create a feature branch
3. Add your improvements
4. Test thoroughly
5. Submit a pull request

---

**Note**: This load testing setup is designed specifically for the Online Boutique microservices demo. Modify the test scenarios and configuration as needed for your specific application requirements.
